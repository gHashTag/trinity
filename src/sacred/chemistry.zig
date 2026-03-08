// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CHEMISTRY — Periodic Table + Chemical Constants v6.0
// 118 Elements + Chemical Calculations
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

// Try to import sacred_const module (available via build.zig)
const sacred_const = if (@hasDecl(@import("builtin"), "test"))
    // Fallback values when testing standalone
    struct {
        pub const physics = struct {
            pub const BOHR_RADIUS: f64 = 0.529e-10;
            pub const RYDBER: f64 = 1.097e7;
        };
        pub const chemistry = struct {
            pub const AVOGADRO: f64 = 6.02214076e23;
            pub const GAS_CONSTANT: f64 = 8.314462618;
            pub const FARADAY: f64 = 96485.33212;
            pub const STANDARD_TEMP: f64 = 273.15;
            pub const STANDARD_PRESSURE: f64 = 101325;
            pub const MOLAR_VOLUME_STP: f64 = 22.414;
        };
    }
else
    @import("const");

// ═══════════════════════════════════════════════════════════════════════════════
// CHEMICAL ELEMENT STRUCTURE
// ═══════════════════════════════════════════════════════════════════════════════

pub const Element = struct {
    number: u8, // Atomic number Z (1-118)
    symbol: []const u8, // 1-2 letter symbol
    name: []const u8, // Full name
    mass: f64, // Atomic mass (amu) - most common isotope
    mass_std: f64, // Standard atomic weight
    electron_config: []const u8,
    group: u8, // Group 1-18
    period: u8, // Period 1-7
    block: u8, // 0=s, 1=p, 2=d, 3=f
    category: []const u8,
    electronegativity: ?f64, // Pauling scale
    ionization_energy: ?f64, // First ionization (eV)
    electron_affinity: ?f64, // Electron affinity (eV)
    atomic_radius: ?f64, // Covalent radius (pm)
    melting_point: ?f64, // Melting point (K)
    boiling_point: ?f64, // Boiling point (K)
    density: ?f64, // Density at STP (g/cm³)
    valence: u8, // Typical valence
    discovery_year: u16, // 0 for ancient
    discoverer: []const u8,
    etymology: []const u8,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PERIODIC TABLE — All 118 Elements
// ═══════════════════════════════════════════════════════════════════════════════

pub const PERIODIC_TABLE = [118]Element{
    // Period 1
    .{ .number = 1, .symbol = "H", .name = "Hydrogen", .mass = 1.008, .mass_std = 1.008, .electron_config = "1s¹", .group = 1, .period = 1, .block = 0, .category = "nonmetal", .electronegativity = 2.20, .ionization_energy = 13.598, .electron_affinity = 72.8, .atomic_radius = 31, .melting_point = 14.01, .boiling_point = 20.28, .density = 0.00008988, .valence = 1, .discovery_year = 0, .discoverer = "ancient", .etymology = "Greek: water-former" },
    .{ .number = 2, .symbol = "He", .name = "Helium", .mass = 4.003, .mass_std = 4.003, .electron_config = "1s²", .group = 18, .period = 1, .block = 0, .category = "noble-gas", .electronegativity = null, .ionization_energy = 24.587, .electron_affinity = null, .atomic_radius = 28, .melting_point = 0.95, .boiling_point = 4.22, .density = 0.0001785, .valence = 0, .discovery_year = 1895, .discoverer = "Janssen, Lockyer", .etymology = "Greek: sun god" },

    // Period 2
    .{ .number = 3, .symbol = "Li", .name = "Lithium", .mass = 6.941, .mass_std = 6.941, .electron_config = "[He]2s¹", .group = 1, .period = 2, .block = 0, .category = "alkali-metal", .electronegativity = 0.98, .ionization_energy = 5.392, .electron_affinity = 59.6, .atomic_radius = 128, .melting_point = 453.65, .boiling_point = 1603, .density = 0.534, .valence = 1, .discovery_year = 1817, .discoverer = "Arfwedson", .etymology = "Greek: lithos (stone)" },
    .{ .number = 4, .symbol = "Be", .name = "Beryllium", .mass = 9.012, .mass_std = 9.012, .electron_config = "[He]2s²", .group = 2, .period = 2, .block = 0, .category = "alkaline-earth", .electronegativity = 1.57, .ionization_energy = 9.323, .electron_affinity = null, .atomic_radius = 96, .melting_point = 1560, .boiling_point = 2742, .density = 1.85, .valence = 2, .discovery_year = 1798, .discoverer = "Vauquelin", .etymology = "Greek: beryllos" },
    .{ .number = 5, .symbol = "B", .name = "Boron", .mass = 10.81, .mass_std = 10.81, .electron_config = "[He]2s²2p¹", .group = 13, .period = 2, .block = 1, .category = "metalloid", .electronegativity = 2.04, .ionization_energy = 8.298, .electron_affinity = 26.7, .atomic_radius = 84, .melting_point = 2349, .boiling_point = 4200, .density = 2.34, .valence = 3, .discovery_year = 1808, .discoverer = "Gay-Lussac, Thénard", .etymology = "Greek: borax" },
    .{ .number = 6, .symbol = "C", .name = "Carbon", .mass = 12.011, .mass_std = 12.011, .electron_config = "[He]2s²2p²", .group = 14, .period = 2, .block = 1, .category = "nonmetal", .electronegativity = 2.55, .ionization_energy = 11.260, .electron_affinity = 121.8, .atomic_radius = 76, .melting_point = 3823, .boiling_point = 4300, .density = 2.267, .valence = 4, .discovery_year = 0, .discoverer = "ancient", .etymology = "Latin: carbo (coal)" },
    .{ .number = 7, .symbol = "N", .name = "Nitrogen", .mass = 14.007, .mass_std = 14.007, .electron_config = "[He]2s²2p³", .group = 15, .period = 2, .block = 1, .category = "nonmetal", .electronegativity = 3.04, .ionization_energy = 14.534, .electron_affinity = null, .atomic_radius = 71, .melting_point = 63.15, .boiling_point = 77.36, .density = 0.001251, .valence = 5, .discovery_year = 1772, .discoverer = "Rutherford", .etymology = "Greek: nitron genes" },
    .{ .number = 8, .symbol = "O", .name = "Oxygen", .mass = 15.999, .mass_std = 15.999, .electron_config = "[He]2s²2p⁴", .group = 16, .period = 2, .block = 1, .category = "nonmetal", .electronegativity = 3.44, .ionization_energy = 13.618, .electron_affinity = 140.9, .atomic_radius = 66, .melting_point = 54.36, .boiling_point = 90.20, .density = 0.001429, .valence = 6, .discovery_year = 1774, .discoverer = "Priestley, Scheele", .etymology = "Greek: acid-former" },
    .{ .number = 9, .symbol = "F", .name = "Fluorine", .mass = 18.998, .mass_std = 18.998, .electron_config = "[He]2s²2p⁵", .group = 17, .period = 2, .block = 1, .category = "halogen", .electronegativity = 3.98, .ionization_energy = 17.423, .electron_affinity = 328.0, .atomic_radius = 57, .melting_point = 53.53, .boiling_point = 85.01, .density = 0.001696, .valence = 7, .discovery_year = 1886, .discoverer = "Moissan", .etymology = "Latin: fluere (flow)" },
    .{ .number = 10, .symbol = "Ne", .name = "Neon", .mass = 20.180, .mass_std = 20.180, .electron_config = "[He]2s²2p⁶", .group = 18, .period = 2, .block = 1, .category = "noble-gas", .electronegativity = null, .ionization_energy = 21.565, .electron_affinity = null, .atomic_radius = 58, .melting_point = 24.56, .boiling_point = 27.07, .density = 0.0008999, .valence = 0, .discovery_year = 1898, .discoverer = "Ramsay, Travers", .etymology = "Greek: neos (new)" },

    // Period 3 (simplified subset for brevity)
    .{ .number = 11, .symbol = "Na", .name = "Sodium", .mass = 22.990, .mass_std = 22.990, .electron_config = "[Ne]3s¹", .group = 1, .period = 3, .block = 0, .category = "alkali-metal", .electronegativity = 0.93, .ionization_energy = 5.139, .electron_affinity = 52.8, .atomic_radius = 166, .melting_point = 371.0, .boiling_point = 1156, .density = 0.968, .valence = 1, .discovery_year = 1807, .discoverer = "Davy", .etymology = "English: soda" },
    .{ .number = 12, .symbol = "Mg", .name = "Magnesium", .mass = 24.305, .mass_std = 24.305, .electron_config = "[Ne]3s²", .group = 2, .period = 3, .block = 0, .category = "alkaline-earth", .electronegativity = 1.31, .ionization_energy = 7.646, .electron_affinity = null, .atomic_radius = 141, .melting_point = 923, .boiling_point = 1363, .density = 1.738, .valence = 2, .discovery_year = 1755, .discoverer = "Black", .etymology = "Greek: Magnesia district" },
    .{ .number = 13, .symbol = "Al", .name = "Aluminium", .mass = 26.982, .mass_std = 26.982, .electron_config = "[Ne]3s²3p¹", .group = 13, .period = 3, .block = 1, .category = "post-transition", .electronegativity = 1.61, .ionization_energy = 5.986, .electron_affinity = 42.5, .atomic_radius = 121, .melting_point = 933, .boiling_point = 2743, .density = 2.70, .valence = 3, .discovery_year = 1825, .discoverer = "Oersted", .etymology = "Latin: alumen (alum)" },
    .{ .number = 14, .symbol = "Si", .name = "Silicon", .mass = 28.086, .mass_std = 28.086, .electron_config = "[Ne]3s²3p²", .group = 14, .period = 3, .block = 1, .category = "metalloid", .electronegativity = 1.90, .ionization_energy = 8.152, .electron_affinity = 133.6, .atomic_radius = 111, .melting_point = 1687, .boiling_point = 3538, .density = 2.3296, .valence = 4, .discovery_year = 1824, .discoverer = "Berzelius", .etymology = "Latin: silex (flint)" },
    .{ .number = 15, .symbol = "P", .name = "Phosphorus", .mass = 30.974, .mass_std = 30.974, .electron_config = "[Ne]3s²3p³", .group = 15, .period = 3, .block = 1, .category = "nonmetal", .electronegativity = 2.19, .ionization_energy = 10.487, .electron_affinity = 72.0, .atomic_radius = 98, .melting_point = 317, .boiling_point = 550, .density = 1.823, .valence = 5, .discovery_year = 1669, .discoverer = "Brand", .etymology = "Greek: phosphoros (light-bearer)" },
    .{ .number = 16, .symbol = "S", .name = "Sulfur", .mass = 32.06, .mass_std = 32.06, .electron_config = "[Ne]3s²3p⁴", .group = 16, .period = 3, .block = 1, .category = "nonmetal", .electronegativity = 2.58, .ionization_energy = 10.360, .electron_affinity = 200.4, .atomic_radius = 88, .melting_point = 388, .boiling_point = 717, .density = 2.067, .valence = 6, .discovery_year = 0, .discoverer = "ancient", .etymology = "Sanskrit: sulvere" },
    .{ .number = 17, .symbol = "Cl", .name = "Chlorine", .mass = 35.45, .mass_std = 35.45, .electron_config = "[Ne]3s²3p⁵", .group = 17, .period = 3, .block = 1, .category = "halogen", .electronegativity = 3.16, .ionization_energy = 12.968, .electron_affinity = 349.0, .atomic_radius = 79, .melting_point = 171, .boiling_point = 239, .density = 0.003214, .valence = 7, .discovery_year = 1774, .discoverer = "Scheele", .etymology = "Greek: chloros (green)" },
    .{ .number = 18, .symbol = "Ar", .name = "Argon", .mass = 39.948, .mass_std = 39.948, .electron_config = "[Ne]3s²3p⁶", .group = 18, .period = 3, .block = 1, .category = "noble-gas", .electronegativity = null, .ionization_energy = 15.760, .electron_affinity = null, .atomic_radius = 71, .melting_point = 83.8, .boiling_point = 87.3, .density = 0.001784, .valence = 0, .discovery_year = 1894, .discoverer = "Rayleigh, Ramsay", .etymology = "Greek: argos (lazy)" },

    // Period 4 (first transition metals) - FULL DATA
    .{ .number = 19, .symbol = "K", .name = "Potassium", .mass = 39.098, .mass_std = 39.098, .electron_config = "[Ar]4s¹", .group = 1, .period = 4, .block = 0, .category = "alkali-metal", .electronegativity = 0.82, .ionization_energy = 4.3407, .electron_affinity = 48.4, .atomic_radius = 231, .melting_point = 336.53, .boiling_point = 1032, .density = 0.89, .valence = 1, .discovery_year = 1807, .discoverer = "Davy", .etymology = "Arabic: al-qali (potash)" },
    .{ .number = 20, .symbol = "Ca", .name = "Calcium", .mass = 40.078, .mass_std = 40.078, .electron_config = "[Ar]4s²", .group = 2, .period = 4, .block = 0, .category = "alkaline-earth", .electronegativity = 1.00, .ionization_energy = 6.1132, .electron_affinity = 2.37, .atomic_radius = 197, .melting_point = 1115, .boiling_point = 1757, .density = 1.55, .valence = 2, .discovery_year = 1808, .discoverer = "Davy", .etymology = "Latin: calx (lime)" },
    .{ .number = 21, .symbol = "Sc", .name = "Scandium", .mass = 44.956, .mass_std = 44.956, .electron_config = "[Ar]3d¹4s²", .group = 3, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.36, .ionization_energy = 6.5615, .electron_affinity = 18.1, .atomic_radius = 162, .melting_point = 1814, .boiling_point = 3109, .density = 2.985, .valence = 3, .discovery_year = 1879, .discoverer = "Nilson", .etymology = "Scandia" },
    .{ .number = 22, .symbol = "Ti", .name = "Titanium", .mass = 47.867, .mass_std = 47.867, .electron_config = "[Ar]3d²4s²", .group = 4, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.54, .ionization_energy = 6.8281, .electron_affinity = 7.6, .atomic_radius = 147, .melting_point = 1941, .boiling_point = 3560, .density = 4.506, .valence = 4, .discovery_year = 1791, .discoverer = "Gregor", .etymology = "Titans" },
    .{ .number = 23, .symbol = "V", .name = "Vanadium", .mass = 50.942, .mass_std = 50.942, .electron_config = "[Ar]3d³4s²", .group = 5, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.63, .ionization_energy = 6.7463, .electron_affinity = 50.6, .atomic_radius = 134, .melting_point = 2183, .boiling_point = 3680, .density = 6.0, .valence = 5, .discovery_year = 1801, .discoverer = "del Rio", .etymology = "Vanadis" },
    .{ .number = 24, .symbol = "Cr", .name = "Chromium", .mass = 51.996, .mass_std = 51.996, .electron_config = "[Ar]3d⁵4s¹", .group = 6, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.66, .ionization_energy = 6.7665, .electron_affinity = 64.3, .atomic_radius = 128, .melting_point = 2180, .boiling_point = 2944, .density = 7.19, .valence = 6, .discovery_year = 1797, .discoverer = "Vauquelin", .etymology = "Greek: chroma (color)" },
    .{ .number = 25, .symbol = "Mn", .name = "Manganese", .mass = 54.938, .mass_std = 54.938, .electron_config = "[Ar]3d⁵4s²", .group = 7, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.55, .ionization_energy = 7.4340, .electron_affinity = null, .atomic_radius = 127, .melting_point = 1519, .boiling_point = 2334, .density = 7.21, .valence = 7, .discovery_year = 1774, .discoverer = "Gahn", .etymology = "Latin: magnes" },
    .{ .number = 26, .symbol = "Fe", .name = "Iron", .mass = 55.845, .mass_std = 55.845, .electron_config = "[Ar]3d⁶4s²", .group = 8, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.83, .ionization_energy = 7.9024, .electron_affinity = 15.7, .atomic_radius = 126, .melting_point = 1811, .boiling_point = 3134, .density = 7.874, .valence = 3, .discovery_year = 0, .discoverer = "ancient", .etymology = "English/iron" },
    .{ .number = 27, .symbol = "Co", .name = "Cobalt", .mass = 58.933, .mass_std = 58.933, .electron_config = "[Ar]3d⁷4s²", .group = 9, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.88, .ionization_energy = 7.8810, .electron_affinity = 63.7, .atomic_radius = 125, .melting_point = 1768, .boiling_point = 3200, .density = 8.90, .valence = 3, .discovery_year = 1735, .discoverer = "Brandt", .etymology = "German: kobold" },
    .{ .number = 28, .symbol = "Ni", .name = "Nickel", .mass = 58.693, .mass_std = 58.693, .electron_config = "[Ar]3d⁸4s²", .group = 10, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.91, .ionization_energy = 7.6398, .electron_affinity = 111.5, .atomic_radius = 124, .melting_point = 1728, .boiling_point = 3186, .density = 8.908, .valence = 2, .discovery_year = 1751, .discoverer = "Cronstedt", .etymology = "German: Kupfernickel" },
    .{ .number = 29, .symbol = "Cu", .name = "Copper", .mass = 63.546, .mass_std = 63.546, .electron_config = "[Ar]3d¹⁰4s¹", .group = 11, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.90, .ionization_energy = 7.7264, .electron_affinity = 118.4, .atomic_radius = 128, .melting_point = 1357.77, .boiling_point = 2835, .density = 8.96, .valence = 2, .discovery_year = 0, .discoverer = "ancient", .etymology = "Latin: Cyprus (island)" },
    .{ .number = 30, .symbol = "Zn", .name = "Zinc", .mass = 65.38, .mass_std = 65.38, .electron_config = "[Ar]3d¹⁰4s²", .group = 12, .period = 4, .block = 2, .category = "transition-metal", .electronegativity = 1.65, .ionization_energy = 9.3942, .electron_affinity = null, .atomic_radius = 134, .melting_point = 692.68, .boiling_point = 1180, .density = 7.14, .valence = 2, .discovery_year = 0, .discoverer = "ancient", .etymology = "German: zink" },

    // Period 4 continued (p-block)
    .{ .number = 31, .symbol = "Ga", .name = "Gallium", .mass = 69.723, .mass_std = 69.723, .electron_config = "[Ar]3d¹⁰4s²4p¹", .group = 13, .period = 4, .block = 1, .category = "post-transition", .electronegativity = 1.81, .ionization_energy = 5.9993, .electron_affinity = 28.9, .atomic_radius = 135, .melting_point = 302.91, .boiling_point = 2477, .density = 5.91, .valence = 3, .discovery_year = 1875, .discoverer = "Lecoq de Boisbaudran", .etymology = "Latin: Gallia" },
    .{ .number = 32, .symbol = "Ge", .name = "Germanium", .mass = 72.630, .mass_std = 72.630, .electron_config = "[Ar]3d¹⁰4s²4p²", .group = 14, .period = 4, .block = 1, .category = "metalloid", .electronegativity = 2.01, .ionization_energy = 7.8994, .electron_affinity = 118.9, .atomic_radius = 125, .melting_point = 1211.40, .boiling_point = 3106, .density = 5.323, .valence = 4, .discovery_year = 1886, .discoverer = "Winkler", .etymology = "Latin: Germania" },
    .{ .number = 33, .symbol = "As", .name = "Arsenic", .mass = 74.922, .mass_std = 74.922, .electron_config = "[Ar]3d¹⁰4s²4p³", .group = 15, .period = 4, .block = 1, .category = "metalloid", .electronegativity = 2.18, .ionization_energy = 9.7886, .electron_affinity = 78, .atomic_radius = 114, .melting_point = 1090, .boiling_point = 887, .density = 5.727, .valence = 5, .discovery_year = 1250, .discoverer = "ancient", .etymology = "Greek: arsenikon" },
    .{ .number = 34, .symbol = "Se", .name = "Selenium", .mass = 78.971, .mass_std = 78.971, .electron_config = "[Ar]3d¹⁰4s²4p⁴", .group = 16, .period = 4, .block = 1, .category = "nonmetal", .electronegativity = 2.55, .ionization_energy = 9.752, .electron_affinity = 195.0, .atomic_radius = 103, .melting_point = 494, .boiling_point = 958, .density = 4.81, .valence = 6, .discovery_year = 1817, .discoverer = "Berzelius", .etymology = "Greek: selene (moon)" },
    .{ .number = 35, .symbol = "Br", .name = "Bromine", .mass = 79.904, .mass_std = 79.904, .electron_config = "[Ar]3d¹⁰4s²4p⁵", .group = 17, .period = 4, .block = 1, .category = "halogen", .electronegativity = 2.96, .ionization_energy = 11.8138, .electron_affinity = 324.6, .atomic_radius = 94, .melting_point = 265.8, .boiling_point = 332.0, .density = 3.102, .valence = 7, .discovery_year = 1826, .discoverer = "Balard", .etymology = "Greek: bromos (stench)" },
    .{ .number = 36, .symbol = "Kr", .name = "Krypton", .mass = 83.798, .mass_std = 83.798, .electron_config = "[Ar]3d¹⁰4s²4p⁶", .group = 18, .period = 4, .block = 1, .category = "noble-gas", .electronegativity = 3.00, .ionization_energy = 14.000, .electron_affinity = null, .atomic_radius = 88, .melting_point = 115.79, .boiling_point = 119.93, .density = 0.003733, .valence = 0, .discovery_year = 1898, .discoverer = "Ramsay, Travers", .etymology = "Greek: kryptos (hidden)" },

    // Period 5 (key elements + Rb, Sr, Y, Zr-Ru, Rh, Pd, Cd-Sn, Sb, Te) - FULL DATA
    .{ .number = 37, .symbol = "Rb", .name = "Rubidium", .mass = 85.468, .mass_std = 85.468, .electron_config = "[Kr]5s¹", .group = 1, .period = 5, .block = 0, .category = "alkali-metal", .electronegativity = 0.82, .ionization_energy = 4.1771, .electron_affinity = 46.9, .atomic_radius = 248, .melting_point = 312.46, .boiling_point = 961, .density = 1.532, .valence = 1, .discovery_year = 1861, .discoverer = "Bunsen, Kirchhoff", .etymology = "Latin: rubidus (red)" },
    .{ .number = 38, .symbol = "Sr", .name = "Strontium", .mass = 87.62, .mass_std = 87.62, .electron_config = "[Kr]5s²", .group = 2, .period = 5, .block = 0, .category = "alkaline-earth", .electronegativity = 0.95, .ionization_energy = 5.6949, .electron_affinity = 5.03, .atomic_radius = 215, .melting_point = 1050, .boiling_point = 1655, .density = 2.64, .valence = 2, .discovery_year = 1790, .discoverer = "Crawford", .etymology = "Strontian" },
    .{ .number = 39, .symbol = "Y", .name = "Yttrium", .mass = 88.906, .mass_std = 88.906, .electron_config = "[Kr]4d¹5s²", .group = 3, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 1.22, .ionization_energy = 6.2173, .electron_affinity = 29.6, .atomic_radius = 180, .melting_point = 1799, .boiling_point = 3609, .density = 4.472, .valence = 3, .discovery_year = 1794, .discoverer = "Gadolin", .etymology = "Ytterby" },
    .{ .number = 40, .symbol = "Zr", .name = "Zirconium", .mass = 91.224, .mass_std = 91.224, .electron_config = "[Kr]4d²5s²", .group = 4, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 1.33, .ionization_energy = 6.6339, .electron_affinity = 41.1, .atomic_radius = 160, .melting_point = 2128, .boiling_point = 4682, .density = 6.52, .valence = 4, .discovery_year = 1789, .discoverer = "Klaproth", .etymology = "Arabic: zarkun (gold-like)" },
    .{ .number = 41, .symbol = "Nb", .name = "Niobium", .mass = 92.906, .mass_std = 92.906, .electron_config = "[Kr]4d⁴5s¹", .group = 5, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 1.6, .ionization_energy = 6.7589, .electron_affinity = 86.1, .atomic_radius = 146, .melting_point = 2750, .boiling_point = 5017, .density = 8.57, .valence = 5, .discovery_year = 1801, .discoverer = "Hatchett", .etymology = "Niobe" },
    .{ .number = 42, .symbol = "Mo", .name = "Molybdenum", .mass = 95.95, .mass_std = 95.95, .electron_config = "[Kr]4d⁵5s¹", .group = 6, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 2.16, .ionization_energy = 7.0924, .electron_affinity = 71.7, .atomic_radius = 139, .melting_point = 2896, .boiling_point = 4912, .density = 10.28, .valence = 6, .discovery_year = 1781, .discoverer = "Hjelm", .etymology = "Greek: molybdos (lead)" },
    .{ .number = 43, .symbol = "Tc", .name = "Technetium", .mass = 98.0, .mass_std = 98.0, .electron_config = "[Kr]4d⁵5s²", .group = 7, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 1.9, .ionization_energy = 7.28, .electron_affinity = 53, .atomic_radius = 136, .melting_point = 2430, .boiling_point = 4538, .density = 11.0, .valence = 7, .discovery_year = 1937, .discoverer = "Perrier, Segrè", .etymology = "Greek: technetos (artificial)" },
    .{ .number = 44, .symbol = "Ru", .name = "Ruthenium", .mass = 101.07, .mass_std = 101.07, .electron_config = "[Kr]4d⁷5s¹", .group = 8, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 2.2, .ionization_energy = 7.3605, .electron_affinity = 101.8, .atomic_radius = 134, .melting_point = 2607, .boiling_point = 4423, .density = 12.45, .valence = 3, .discovery_year = 1844, .discoverer = "Klaus", .etymology = "Latin: Ruthenia" },
    .{ .number = 45, .symbol = "Rh", .name = "Rhodium", .mass = 102.91, .mass_std = 102.91, .electron_config = "[Kr]4d⁸5s¹", .group = 9, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 2.28, .ionization_energy = 7.4589, .electron_affinity = 109.7, .atomic_radius = 134, .melting_point = 2237, .boiling_point = 3968, .density = 12.41, .valence = 3, .discovery_year = 1803, .discoverer = "Wollaston", .etymology = "Greek: rhodon (rose)" },
    .{ .number = 46, .symbol = "Pd", .name = "Palladium", .mass = 106.42, .mass_std = 106.42, .electron_config = "[Kr]4d¹⁰", .group = 10, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 2.20, .ionization_energy = 8.3369, .electron_affinity = 53.7, .atomic_radius = 137, .melting_point = 1828.05, .boiling_point = 3236, .density = 12.023, .valence = 2, .discovery_year = 1803, .discoverer = "Wollaston", .etymology = "Pallas" },
    .{ .number = 47, .symbol = "Ag", .name = "Silver", .mass = 107.868, .mass_std = 107.868, .electron_config = "[Kr]4d¹⁰5s¹", .group = 11, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 1.93, .ionization_energy = 7.5762, .electron_affinity = 125.6, .atomic_radius = 144, .melting_point = 1234.93, .boiling_point = 2435, .density = 10.501, .valence = 1, .discovery_year = 0, .discoverer = "ancient", .etymology = "English/soft" },
    .{ .number = 48, .symbol = "Cd", .name = "Cadmium", .mass = 112.41, .mass_std = 112.41, .electron_config = "[Kr]4d¹⁰5s²", .group = 12, .period = 5, .block = 2, .category = "transition-metal", .electronegativity = 1.69, .ionization_energy = 8.9938, .electron_affinity = null, .atomic_radius = 151, .melting_point = 594.22, .boiling_point = 1040, .density = 8.65, .valence = 2, .discovery_year = 1817, .discoverer = "Stromeyer", .etymology = "Latin: cadmia" },
    .{ .number = 49, .symbol = "In", .name = "Indium", .mass = 114.82, .mass_std = 114.82, .electron_config = "[Kr]4d¹⁰5s²5p¹", .group = 13, .period = 5, .block = 1, .category = "post-transition", .electronegativity = 1.78, .ionization_energy = 5.7864, .electron_affinity = 28.9, .atomic_radius = 156, .melting_point = 429.75, .boiling_point = 2345, .density = 7.31, .valence = 3, .discovery_year = 1863, .discoverer = "Reich, Richter", .etymology = "Latin: indicum (indigo)" },
    .{ .number = 50, .symbol = "Sn", .name = "Tin", .mass = 118.71, .mass_std = 118.71, .electron_config = "[Kr]4d¹⁰5s²5p²", .group = 14, .period = 5, .block = 1, .category = "post-transition", .electronegativity = 1.96, .ionization_energy = 7.3439, .electron_affinity = 107.3, .atomic_radius = 145, .melting_point = 505.08, .boiling_point = 2875, .density = 7.365, .valence = 4, .discovery_year = 0, .discoverer = "ancient", .etymology = "English/origin" },
    .{ .number = 51, .symbol = "Sb", .name = "Antimony", .mass = 121.76, .mass_std = 121.76, .electron_config = "[Kr]4d¹⁰5s²5p³", .group = 15, .period = 5, .block = 1, .category = "metalloid", .electronegativity = 2.05, .ionization_energy = 8.6084, .electron_affinity = 100.9, .atomic_radius = 133, .melting_point = 903.78, .boiling_point = 1860, .density = 6.697, .valence = 5, .discovery_year = 0, .discoverer = "ancient", .etymology = "Greek: anti + monos" },
    .{ .number = 52, .symbol = "Te", .name = "Tellurium", .mass = 127.60, .mass_std = 127.60, .electron_config = "[Kr]4d¹⁰5s²5p⁴", .group = 16, .period = 5, .block = 1, .category = "metalloid", .electronegativity = 2.1, .ionization_energy = 9.009, .electron_affinity = 190.2, .atomic_radius = 123, .melting_point = 722.66, .boiling_point = 1261, .density = 6.24, .valence = 6, .discovery_year = 1783, .discoverer = "von Reichenstein", .etymology = "Latin: tellus (earth)" },
    .{ .number = 53, .symbol = "I", .name = "Iodine", .mass = 126.904, .mass_std = 126.904, .electron_config = "[Kr]4d¹⁰5s²5p⁵", .group = 17, .period = 5, .block = 1, .category = "halogen", .electronegativity = 2.66, .ionization_energy = 10.4513, .electron_affinity = 295.2, .atomic_radius = 115, .melting_point = 386.85, .boiling_point = 457.4, .density = 4.933, .valence = 7, .discovery_year = 1811, .discoverer = "Courtois", .etymology = "Greek: iodes (violet)" },
    .{ .number = 54, .symbol = "Xe", .name = "Xenon", .mass = 131.293, .mass_std = 131.293, .electron_config = "[Kr]4d¹⁰5s²5p⁶", .group = 18, .period = 5, .block = 1, .category = "noble-gas", .electronegativity = 2.6, .ionization_energy = 12.1298, .electron_affinity = null, .atomic_radius = 108, .melting_point = 161.4, .boiling_point = 165.03, .density = 0.005887, .valence = 0, .discovery_year = 1898, .discoverer = "Ramsay, Travers", .etymology = "Greek: xenos (stranger)" },

    // Period 6 (Cs, Ba, Lanthanides, Hf-Pt, Au, Hg, Tl-Rn) - FULL DATA
    .{ .number = 55, .symbol = "Cs", .name = "Caesium", .mass = 132.91, .mass_std = 132.91, .electron_config = "[Xe]6s¹", .group = 1, .period = 6, .block = 0, .category = "alkali-metal", .electronegativity = 0.79, .ionization_energy = 3.8939, .electron_affinity = 45.5, .atomic_radius = 265, .melting_point = 301.59, .boiling_point = 944, .density = 1.93, .valence = 1, .discovery_year = 1860, .discoverer = "Bunsen, Kirchhoff", .etymology = "Latin: caesius (sky blue)" },
    .{ .number = 56, .symbol = "Ba", .name = "Barium", .mass = 137.33, .mass_std = 137.33, .electron_config = "[Xe]6s²", .group = 2, .period = 6, .block = 0, .category = "alkaline-earth", .electronegativity = 0.89, .ionization_energy = 5.2117, .electron_affinity = 13.95, .atomic_radius = 222, .melting_point = 1000, .boiling_point = 2170, .density = 3.51, .valence = 2, .discovery_year = 1808, .discoverer = "Davy", .etymology = "Greek: barys (heavy)" },
    // Lanthanides 57-71
    .{ .number = 57, .symbol = "La", .name = "Lanthanum", .mass = 138.91, .mass_std = 138.91, .electron_config = "[Xe]5d¹6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.10, .ionization_energy = 5.5770, .electron_affinity = 48, .atomic_radius = 187, .melting_point = 1193, .boiling_point = 3737, .density = 6.162, .valence = 3, .discovery_year = 1839, .discoverer = "Mosander", .etymology = "Greek: lanthanein (hidden)" },
    .{ .number = 58, .symbol = "Ce", .name = "Cerium", .mass = 140.12, .mass_std = 140.12, .electron_config = "[Xe]4f¹5d¹6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.12, .ionization_energy = 5.5387, .electron_affinity = 50, .atomic_radius = 182, .melting_point = 1068, .boiling_point = 3716, .density = 6.770, .valence = 3, .discovery_year = 1803, .discoverer = "Berzelius", .etymology = "Ceres" },
    .{ .number = 59, .symbol = "Pr", .name = "Praseodymium", .mass = 140.91, .mass_std = 140.91, .electron_config = "[Xe]4f³6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.13, .ionization_energy = 5.473, .electron_affinity = 50, .atomic_radius = 182, .melting_point = 1208, .boiling_point = 3793, .density = 6.77, .valence = 3, .discovery_year = 1885, .discoverer = "von Welsbach", .etymology = "Greek: prasios (green)" },
    .{ .number = 60, .symbol = "Nd", .name = "Neodymium", .mass = 144.24, .mass_std = 144.24, .electron_config = "[Xe]4f⁴6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.14, .ionization_energy = 5.5250, .electron_affinity = 50, .atomic_radius = 181, .melting_point = 1297, .boiling_point = 3347, .density = 7.01, .valence = 3, .discovery_year = 1885, .discoverer = "von Welsbach", .etymology = "Greek: neos (new)" },
    .{ .number = 61, .symbol = "Pm", .name = "Promethium", .mass = 145.0, .mass_std = 145.0, .electron_config = "[Xe]4f⁵6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.13, .ionization_energy = 5.582, .electron_affinity = 50, .atomic_radius = 181, .melting_point = 1315, .boiling_point = 3273, .density = 7.26, .valence = 3, .discovery_year = 1945, .discoverer = "Marinsky, Glendenin", .etymology = "Prometheus" },
    .{ .number = 62, .symbol = "Sm", .name = "Samarium", .mass = 150.36, .mass_std = 150.36, .electron_config = "[Xe]4f⁶6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.17, .ionization_energy = 5.6437, .electron_affinity = 50, .atomic_radius = 180, .melting_point = 1345, .boiling_point = 2067, .density = 7.52, .valence = 3, .discovery_year = 1879, .discoverer = "Lecoq de Boisbaudran", .etymology = "Samarskite" },
    .{ .number = 63, .symbol = "Eu", .name = "Europium", .mass = 151.96, .mass_std = 151.96, .electron_config = "[Xe]4f⁷6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.2, .ionization_energy = 5.6704, .electron_affinity = 50, .atomic_radius = 199, .melting_point = 1099, .boiling_point = 1802, .density = 5.244, .valence = 3, .discovery_year = 1901, .discoverer = "Demarcay", .etymology = "Europe" },
    .{ .number = 64, .symbol = "Gd", .name = "Gadolinium", .mass = 157.25, .mass_std = 157.25, .electron_config = "[Xe]4f⁷5d¹6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.20, .ionization_energy = 6.1498, .electron_affinity = 50, .atomic_radius = 178, .melting_point = 1585, .boiling_point = 3546, .density = 7.90, .valence = 3, .discovery_year = 1880, .discoverer = "Marignac", .etymology = "Johan Gadolin" },
    .{ .number = 65, .symbol = "Tb", .name = "Terbium", .mass = 158.93, .mass_std = 158.93, .electron_config = "[Xe]4f⁹6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.2, .ionization_energy = 5.8638, .electron_affinity = 50, .atomic_radius = 177, .melting_point = 1629, .boiling_point = 3503, .density = 8.23, .valence = 3, .discovery_year = 1843, .discoverer = "Mosander", .etymology = "Ytterby" },
    .{ .number = 66, .symbol = "Dy", .name = "Dysprosium", .mass = 162.50, .mass_std = 162.50, .electron_config = "[Xe]4f¹⁰6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.22, .ionization_energy = 5.9389, .electron_affinity = 50, .atomic_radius = 178, .melting_point = 1680, .boiling_point = 2840, .density = 8.540, .valence = 3, .discovery_year = 1886, .discoverer = "Lecoq de Boisbaudran", .etymology = "Greek: dysprositos (hard)" },
    .{ .number = 67, .symbol = "Ho", .name = "Holmium", .mass = 164.93, .mass_std = 164.93, .electron_config = "[Xe]4f¹¹6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.23, .ionization_energy = 6.0215, .electron_affinity = 50, .atomic_radius = 176, .melting_point = 1734, .boiling_point = 2993, .density = 8.79, .valence = 3, .discovery_year = 1878, .discoverer = "Cleve", .etymology = "Holmia (Stockholm)" },
    .{ .number = 68, .symbol = "Er", .name = "Erbium", .mass = 167.26, .mass_std = 167.26, .electron_config = "[Xe]4f¹²6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.24, .ionization_energy = 6.1077, .electron_affinity = 50, .atomic_radius = 175, .melting_point = 1802, .boiling_point = 3141, .density = 9.066, .valence = 3, .discovery_year = 1843, .discoverer = "Mosander", .etymology = "Ytterby" },
    .{ .number = 69, .symbol = "Tm", .name = "Thulium", .mass = 168.93, .mass_std = 168.93, .electron_config = "[Xe]4f¹³6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.25, .ionization_energy = 6.1843, .electron_affinity = 50, .atomic_radius = 174, .melting_point = 1818, .boiling_point = 2223, .density = 9.32, .valence = 3, .discovery_year = 1879, .discoverer = "Cleve", .etymology = "Thule" },
    .{ .number = 70, .symbol = "Yb", .name = "Ytterbium", .mass = 173.05, .mass_std = 173.05, .electron_config = "[Xe]4f¹⁴6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.1, .ionization_energy = 6.2542, .electron_affinity = 50, .atomic_radius = 194, .melting_point = 1097, .boiling_point = 1469, .density = 6.90, .valence = 3, .discovery_year = 1878, .discoverer = "Marignac", .etymology = "Ytterby" },
    .{ .number = 71, .symbol = "Lu", .name = "Lutetium", .mass = 174.97, .mass_std = 174.97, .electron_config = "[Xe]4f¹⁴5d¹6s²", .group = 3, .period = 6, .block = 3, .category = "lanthanide", .electronegativity = 1.27, .ionization_energy = 5.4259, .electron_affinity = 50, .atomic_radius = 175, .melting_point = 1925, .boiling_point = 3675, .density = 9.841, .valence = 3, .discovery_year = 1907, .discoverer = "Urbain", .etymology = "Lutetia (Paris)" },
    // Elements 72-78
    .{ .number = 72, .symbol = "Hf", .name = "Hafnium", .mass = 178.49, .mass_std = 178.49, .electron_config = "[Xe]4f¹⁴5d²6s²", .group = 4, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 1.3, .ionization_energy = 6.8251, .electron_affinity = 0, .atomic_radius = 159, .melting_point = 2506, .boiling_point = 4876, .density = 13.31, .valence = 4, .discovery_year = 1923, .discoverer = "Coster, von Hevesy", .etymology = "Hafnia (Copenhagen)" },
    .{ .number = 73, .symbol = "Ta", .name = "Tantalum", .mass = 180.95, .mass_std = 180.95, .electron_config = "[Xe]4f¹⁴5d³6s²", .group = 5, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 1.5, .ionization_energy = 7.5496, .electron_affinity = 31, .atomic_radius = 149, .melting_point = 3290, .boiling_point = 5731, .density = 16.69, .valence = 5, .discovery_year = 1802, .discoverer = "Ekeberg", .etymology = "Tantalus" },
    .{ .number = 74, .symbol = "W", .name = "Tungsten", .mass = 183.84, .mass_std = 183.84, .electron_config = "[Xe]4f¹⁴5d⁴6s²", .group = 6, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 2.36, .ionization_energy = 7.8640, .electron_affinity = 78.6, .atomic_radius = 139, .melting_point = 3695, .boiling_point = 5828, .density = 19.25, .valence = 6, .discovery_year = 1783, .discoverer = "Elhuyar", .etymology = "Swedish: tung sten (heavy stone)" },
    .{ .number = 75, .symbol = "Re", .name = "Rhenium", .mass = 186.21, .mass_std = 186.21, .electron_config = "[Xe]4f¹⁴5d⁵6s²", .group = 7, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 1.9, .ionization_energy = 7.8837, .electron_affinity = 14.5, .atomic_radius = 137, .melting_point = 3459, .boiling_point = 5869, .density = 21.02, .valence = 7, .discovery_year = 1925, .discoverer = "Noddack, Berg", .etymology = "Rhine" },
    .{ .number = 76, .symbol = "Os", .name = "Osmium", .mass = 190.23, .mass_std = 190.23, .electron_config = "[Xe]4f¹⁴5d⁶6s²", .group = 8, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 2.2, .ionization_energy = 8.4382, .electron_affinity = 106.1, .atomic_radius = 135, .melting_point = 3306, .boiling_point = 5285, .density = 22.59, .valence = 3, .discovery_year = 1803, .discoverer = "Tennant", .etymology = "Greek: osme (smell)" },
    .{ .number = 77, .symbol = "Ir", .name = "Iridium", .mass = 192.22, .mass_std = 192.22, .electron_config = "[Xe]4f¹⁴5d⁷6s²", .group = 9, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 2.20, .ionization_energy = 8.9670, .electron_affinity = 150.9, .atomic_radius = 136, .melting_point = 2719, .boiling_point = 4701, .density = 22.56, .valence = 3, .discovery_year = 1803, .discoverer = "Tennant", .etymology = "Latin: iris (rainbow)" },
    .{ .number = 78, .symbol = "Pt", .name = "Platinum", .mass = 195.08, .mass_std = 195.08, .electron_config = "[Xe]4f¹⁴5d⁹6s¹", .group = 10, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 2.28, .ionization_energy = 8.9587, .electron_affinity = 205.3, .atomic_radius = 139, .melting_point = 2041.4, .boiling_point = 4098, .density = 21.45, .valence = 2, .discovery_year = 1735, .discoverer = "Ulloa", .etymology = "Spanish: platina (silver)" },
    // Elements 79-86 (critical)
    .{ .number = 79, .symbol = "Au", .name = "Gold", .mass = 196.967, .mass_std = 196.967, .electron_config = "[Xe]4f¹⁴5d¹⁰6s¹", .group = 11, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 2.54, .ionization_energy = 9.2255, .electron_affinity = 222.8, .atomic_radius = 144, .melting_point = 1337.33, .boiling_point = 3129, .density = 19.32, .valence = 3, .discovery_year = 0, .discoverer = "ancient", .etymology = "English/origin" },
    .{ .number = 80, .symbol = "Hg", .name = "Mercury", .mass = 200.592, .mass_std = 200.592, .electron_config = "[Xe]4f¹⁴5d¹⁰6s²", .group = 12, .period = 6, .block = 2, .category = "transition-metal", .electronegativity = 2.00, .ionization_energy = 10.4375, .electron_affinity = null, .atomic_radius = 150, .melting_point = 234.32, .boiling_point = 629.88, .density = 13.534, .valence = 2, .discovery_year = 0, .discoverer = "ancient", .etymology = "Latin: hydrargyrum (liquid silver)" },
    .{ .number = 81, .symbol = "Tl", .name = "Thallium", .mass = 204.38, .mass_std = 204.38, .electron_config = "[Xe]4f¹⁴5d¹⁰6s²6p¹", .group = 13, .period = 6, .block = 1, .category = "post-transition", .electronegativity = 1.62, .ionization_energy = 6.1082, .electron_affinity = 19.2, .atomic_radius = 156, .melting_point = 577, .boiling_point = 1746, .density = 11.85, .valence = 3, .discovery_year = 1861, .discoverer = "Crookes", .etymology = "Greek: thallos (green shoot)" },
    .{ .number = 82, .symbol = "Pb", .name = "Lead", .mass = 207.2, .mass_std = 207.2, .electron_config = "[Xe]4f¹⁴5d¹⁰6s²6p²", .group = 14, .period = 6, .block = 1, .category = "post-transition", .electronegativity = 2.33, .ionization_energy = 7.4167, .electron_affinity = 35.1, .atomic_radius = 154, .melting_point = 600.61, .boiling_point = 2022, .density = 11.34, .valence = 4, .discovery_year = 0, .discoverer = "ancient", .etymology = "English/lead" },
    .{ .number = 83, .symbol = "Bi", .name = "Bismuth", .mass = 208.98, .mass_std = 208.98, .electron_config = "[Xe]4f¹⁴5d¹⁰6s²6p³", .group = 15, .period = 6, .block = 1, .category = "post-transition", .electronegativity = 2.02, .ionization_energy = 7.2855, .electron_affinity = 91.3, .atomic_radius = 143, .melting_point = 544.7, .boiling_point = 1837, .density = 9.78, .valence = 5, .discovery_year = 0, .discoverer = "ancient", .etymology = "German: weisse masse (white mass)" },
    .{ .number = 84, .symbol = "Po", .name = "Polonium", .mass = 209.0, .mass_std = 209.0, .electron_config = "[Xe]4f¹⁴5d¹⁰6s²6p⁴", .group = 16, .period = 6, .block = 1, .category = "metalloid", .electronegativity = 2.0, .ionization_energy = 8.414, .electron_affinity = 183.3, .atomic_radius = 140, .melting_point = 527, .boiling_point = 1235, .density = 9.196, .valence = 6, .discovery_year = 1898, .discoverer = "Marie Curie", .etymology = "Poland" },
    .{ .number = 85, .symbol = "At", .name = "Astatine", .mass = 210.0, .mass_std = 210.0, .electron_config = "[Xe]4f¹⁴5d¹⁰6s²6p⁵", .group = 17, .period = 6, .block = 1, .category = "halogen", .electronegativity = 2.2, .ionization_energy = 8.86, .electron_affinity = 270.1, .atomic_radius = 150, .melting_point = 575, .boiling_point = 610, .density = 7.0, .valence = 7, .discovery_year = 1940, .discoverer = "Segrè, Mackenzie", .etymology = "Greek: astatos (unstable)" },
    .{ .number = 86, .symbol = "Rn", .name = "Radon", .mass = 222.0, .mass_std = 222.0, .electron_config = "[Xe]4f¹⁴5d¹⁰6s²6p⁶", .group = 18, .period = 6, .block = 1, .category = "noble-gas", .electronegativity = 2.2, .ionization_energy = 10.7485, .electron_affinity = null, .atomic_radius = 120, .melting_point = 202, .boiling_point = 211.3, .density = 0.00973, .valence = 0, .discovery_year = 1900, .discoverer = "Dorn", .etymology = "Radium" },

    // Period 7 (Actinides Fr-Pu) - FULL DATA for key elements
    .{ .number = 87, .symbol = "Fr", .name = "Francium", .mass = 223.0, .mass_std = 223.0, .electron_config = "[Rn]7s¹", .group = 1, .period = 7, .block = 0, .category = "alkali-metal", .electronegativity = 0.7, .ionization_energy = 4.0727, .electron_affinity = 44, .atomic_radius = 270, .melting_point = 300, .boiling_point = 950, .density = 1.87, .valence = 1, .discovery_year = 1939, .discoverer = "Perey", .etymology = "France" },
    .{ .number = 88, .symbol = "Ra", .name = "Radium", .mass = 226.0, .mass_std = 226.0, .electron_config = "[Rn]7s²", .group = 2, .period = 7, .block = 0, .category = "alkaline-earth", .electronegativity = 0.9, .ionization_energy = 5.2784, .electron_affinity = 10, .atomic_radius = 223, .melting_point = 973, .boiling_point = 2010, .density = 5.5, .valence = 2, .discovery_year = 1898, .discoverer = "Curie", .etymology = "Latin: radius (ray)" },
    .{ .number = 89, .symbol = "Ac", .name = "Actinium", .mass = 227.0, .mass_std = 227.0, .electron_config = "[Rn]6d¹7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = 1.1, .ionization_energy = 5.17, .electron_affinity = 35, .atomic_radius = 188, .melting_point = 1323, .boiling_point = 3471, .density = 10.07, .valence = 3, .discovery_year = 1899, .discoverer = "Debierne", .etymology = "Greek: aktis (ray)" },
    .{ .number = 90, .symbol = "Th", .name = "Thorium", .mass = 232.04, .mass_std = 232.04, .electron_config = "[Rn]6d²7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = 1.3, .ionization_energy = 6.3067, .electron_affinity = 50, .atomic_radius = 179, .melting_point = 2115, .boiling_point = 5061, .density = 11.7, .valence = 4, .discovery_year = 1829, .discoverer = "Berzelius", .etymology = "Thor" },
    .{ .number = 91, .symbol = "Pa", .name = "Protactinium", .mass = 231.04, .mass_std = 231.04, .electron_config = "[Rn]5f²6d¹7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = 1.5, .ionization_energy = 5.89, .electron_affinity = 51, .atomic_radius = 163, .melting_point = 1841, .boiling_point = 4300, .density = 15.37, .valence = 5, .discovery_year = 1913, .discoverer = "Fajans, Göhring", .etymology = "Greek: protos (first)" },
    .{ .number = 92, .symbol = "U", .name = "Uranium", .mass = 238.029, .mass_std = 238.029, .electron_config = "[Rn]5f³6d¹7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = 1.38, .ionization_energy = 6.1941, .electron_affinity = 50, .atomic_radius = 156, .melting_point = 1405.3, .boiling_point = 4404, .density = 19.1, .valence = 6, .discovery_year = 1789, .discoverer = "Klaproth", .etymology = "Uranus" },
    .{ .number = 93, .symbol = "Np", .name = "Neptunium", .mass = 237.0, .mass_std = 237.0, .electron_config = "[Rn]5f⁴6d¹7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = 1.36, .ionization_energy = 6.2657, .electron_affinity = 50, .atomic_radius = 155, .melting_point = 917, .boiling_point = 4273, .density = 20.45, .valence = 6, .discovery_year = 1940, .discoverer = "McMillan, Abelson", .etymology = "Neptune" },
    .{ .number = 94, .symbol = "Pu", .name = "Plutonium", .mass = 244.0, .mass_std = 244.0, .electron_config = "[Rn]5f⁶7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = 1.28, .ionization_energy = 6.026, .electron_affinity = 50, .atomic_radius = 159, .melting_point = 912.5, .boiling_point = 3501, .density = 19.816, .valence = 6, .discovery_year = 1940, .discoverer = "Seaborg", .etymology = "Pluto" },

    // Elements 95-118 (Transplutonium elements - simplified, NIST 2025 pending)
    .{ .number = 95, .symbol = "Am", .name = "Americium", .mass = 243.0, .mass_std = 243.0, .electron_config = "[Rn]5f⁷7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1944, .discoverer = "Seaborg", .etymology = "Americas" },
    .{ .number = 96, .symbol = "Cm", .name = "Curium", .mass = 247.0, .mass_std = 247.0, .electron_config = "[Rn]5f⁷6d¹7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1944, .discoverer = "Seaborg", .etymology = "Marie Curie" },
    .{ .number = 97, .symbol = "Bk", .name = "Berkelium", .mass = 247.0, .mass_std = 247.0, .electron_config = "[Rn]5f⁹7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1949, .discoverer = "Seaborg", .etymology = "Berkeley" },
    .{ .number = 98, .symbol = "Cf", .name = "Californium", .mass = 251.0, .mass_std = 251.0, .electron_config = "[Rn]5f¹⁰7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1950, .discoverer = "Seaborg", .etymology = "California" },
    .{ .number = 99, .symbol = "Es", .name = "Einsteinium", .mass = 252.0, .mass_std = 252.0, .electron_config = "[Rn]5f¹¹7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1952, .discoverer = "Ghiorso", .etymology = "Einstein" },
    .{ .number = 100, .symbol = "Fm", .name = "Fermium", .mass = 257.0, .mass_std = 257.0, .electron_config = "[Rn]5f¹²7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1952, .discoverer = "Ghiorso", .etymology = "Enrico Fermi" },
    .{ .number = 101, .symbol = "Md", .name = "Mendelevium", .mass = 258.0, .mass_std = 258.0, .electron_config = "[Rn]5f¹³7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1955, .discoverer = "Ghiorso", .etymology = "Mendeleev" },
    .{ .number = 102, .symbol = "No", .name = "Nobelium", .mass = 259.0, .mass_std = 259.0, .electron_config = "[Rn]5f¹⁴7s²", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1958, .discoverer = "Ghiorso", .etymology = "Nobel" },
    .{ .number = 103, .symbol = "Lr", .name = "Lawrencium", .mass = 266.0, .mass_std = 266.0, .electron_config = "[Rn]5f¹⁴7s²7p¹", .group = 3, .period = 7, .block = 2, .category = "actinide", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1961, .discoverer = "Ghiorso", .etymology = "Ernest Lawrence" },
    .{ .number = 104, .symbol = "Rf", .name = "Rutherfordium", .mass = 267.0, .mass_std = 267.0, .electron_config = "[Rn]5f¹⁴6d²7s²", .group = 4, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 4, .discovery_year = 1969, .discoverer = "Ghiorso", .etymology = "Ernest Rutherford" },
    .{ .number = 105, .symbol = "Db", .name = "Dubnium", .mass = 268.0, .mass_std = 268.0, .electron_config = "[Rn]5f¹⁴6d³7s²", .group = 5, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 5, .discovery_year = 1970, .discoverer = "Ghiorso", .etymology = "Dubna" },
    .{ .number = 106, .symbol = "Sg", .name = "Seaborgium", .mass = 269.0, .mass_std = 269.0, .electron_config = "[Rn]5f¹⁴6d⁴7s²", .group = 6, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 6, .discovery_year = 1974, .discoverer = "Ghiorso", .etymology = "Glenn Seaborg" },
    .{ .number = 107, .symbol = "Bh", .name = "Bohrium", .mass = 270.0, .mass_std = 270.0, .electron_config = "[Rn]5f¹⁴6d⁵7s²", .group = 7, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 7, .discovery_year = 1981, .discoverer = "Münzenberg", .etymology = "Niels Bohr" },
    .{ .number = 108, .symbol = "Hs", .name = "Hassium", .mass = 277.0, .mass_std = 277.0, .electron_config = "[Rn]5f¹⁴6d⁶7s²", .group = 8, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 8, .discovery_year = 1984, .discoverer = "Münzenberg", .etymology = "Hesse" },
    .{ .number = 109, .symbol = "Mt", .name = "Meitnerium", .mass = 278.0, .mass_std = 278.0, .electron_config = "[Rn]5f¹⁴6d⁷7s²", .group = 9, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 9, .discovery_year = 1982, .discoverer = "Münzenberg", .etymology = "Lise Meitner" },
    .{ .number = 110, .symbol = "Ds", .name = "Darmstadtium", .mass = 281.0, .mass_std = 281.0, .electron_config = "[Rn]5f¹⁴6d⁸7s²", .group = 10, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 10, .discovery_year = 1994, .discoverer = "Hofmann", .etymology = "Darmstadt" },
    .{ .number = 111, .symbol = "Rg", .name = "Roentgenium", .mass = 282.0, .mass_std = 282.0, .electron_config = "[Rn]5f¹⁴6d⁹7s²", .group = 11, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 11, .discovery_year = 1994, .discoverer = "Hofmann", .etymology = "Wilhelm Röntgen" },
    .{ .number = 112, .symbol = "Cn", .name = "Copernicium", .mass = 285.0, .mass_std = 285.0, .electron_config = "[Rn]5f¹⁴6d¹⁰7s²", .group = 12, .period = 7, .block = 2, .category = "transition-metal", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 12, .discovery_year = 1996, .discoverer = "Hofmann", .etymology = "Copernicus" },
    .{ .number = 113, .symbol = "Nh", .name = "Nihonium", .mass = 286.0, .mass_std = 286.0, .electron_config = "[Rn]5f¹⁴6d¹⁰7s²7p¹", .group = 13, .period = 7, .block = 1, .category = "post-transition", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 13, .discovery_year = 2004, .discoverer = "Morita", .etymology = "Japan (Nihon)" },
    .{ .number = 114, .symbol = "Fl", .name = "Flerovium", .mass = 289.0, .mass_std = 289.0, .electron_config = "[Rn]5f¹⁴6d¹⁰7s²7p²", .group = 14, .period = 7, .block = 1, .category = "post-transition", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 14, .discovery_year = 1999, .discoverer = "Oganessian", .etymology = "Flerov Laboratory" },
    .{ .number = 115, .symbol = "Mc", .name = "Moscovium", .mass = 290.0, .mass_std = 290.0, .electron_config = "[Rn]5f¹⁴6d¹⁰7s²7p³", .group = 15, .period = 7, .block = 1, .category = "post-transition", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 15, .discovery_year = 2003, .discoverer = "Oganessian", .etymology = "Moscow" },
    .{ .number = 116, .symbol = "Lv", .name = "Livermorium", .mass = 293.0, .mass_std = 293.0, .electron_config = "[Rn]5f¹⁴6d¹⁰7s²7p⁴", .group = 16, .period = 7, .block = 1, .category = "post-transition", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 16, .discovery_year = 2000, .discoverer = "Oganessian", .etymology = "Lawrence Livermore" },
    .{ .number = 117, .symbol = "Ts", .name = "Tennessine", .mass = 294.0, .mass_std = 294.0, .electron_config = "[Rn]5f¹⁴6d¹⁰7s²7p⁵", .group = 17, .period = 7, .block = 1, .category = "halogen", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 17, .discovery_year = 2010, .discoverer = "Oganessian", .etymology = "Tennessee" },
    .{ .number = 118, .symbol = "Og", .name = "Oganesson", .mass = 294.0, .mass_std = 294.0, .electron_config = "[Rn]5f¹⁴6d¹⁰7s²7p⁶", .group = 18, .period = 7, .block = 1, .category = "noble-gas", .electronegativity = null, .ionization_energy = null, .electron_affinity = null, .atomic_radius = null, .melting_point = null, .boiling_point = null, .density = null, .valence = 18, .discovery_year = 2006, .discoverer = "Oganessian", .etymology = "Yuri Oganessian" },
};

// ═══════════════════════════════════════════════════════════════════════════════
// CHEMICAL CONSTANTS (from sacred.const, re-exported for convenience)
// ═══════════════════════════════════════════════════════════════════════════════

pub const AVOGADRO: f64 = sacred_const.chemistry.AVOGADRO;
pub const GAS_CONSTANT: f64 = sacred_const.chemistry.GAS_CONSTANT;
pub const FARADAY: f64 = sacred_const.chemistry.FARADAY;
pub const STANDARD_TEMP: f64 = sacred_const.chemistry.STANDARD_TEMP;
pub const STANDARD_PRESSURE: f64 = sacred_const.chemistry.STANDARD_PRESSURE;
pub const MOLAR_VOLUME_STP: f64 = sacred_const.chemistry.MOLAR_VOLUME_STP;

// ═══════════════════════════════════════════════════════════════════════════════
// ELEMENT LOOKUP FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Get element by symbol (case-insensitive) or atomic number
pub fn getElement(input: anytype) ?*const Element {
    const T = @TypeOf(input);
    if (T == []const u8) {
        // Search by symbol
        const symbol = @as([]const u8, input);
        inline for (&PERIODIC_TABLE) |*elem| {
            if (std.ascii.eqlIgnoreCase(elem.symbol, symbol)) return elem;
        }
        return null;
    } else if (T == u8 or T == u16 or T == u32 or T == i32 or T == i64 or T == usize) {
        // Search by atomic number
        const num = @as(u8, @intCast(input));
        if (num >= 1 and num <= 118) return &PERIODIC_TABLE[num - 1];
        return null;
    }
    return null;
}

/// Parse chemical formula into element counts
/// Returns map of element symbol -> count
pub fn parseFormula(allocator: std.mem.Allocator, formula: []const u8) !std.StringHashMap(u32) {
    var result = std.StringHashMap(u32).init(allocator);

    var i: usize = 0;
    while (i < formula.len) {
        // Parse element symbol (1-2 letters, uppercase)
        const start = i;
        i += 1;
        if (i < formula.len and std.ascii.isLower(formula[i])) {
            i += 1; // Two-letter symbol
        }
        const symbol = formula[start..i];

        // Parse subscript number
        var count: u32 = 1;
        if (i < formula.len and std.ascii.isDigit(formula[i])) {
            const num_start = i;
            while (i < formula.len and std.ascii.isDigit(formula[i])) : (i += 1) {}
            count = try std.fmt.parseInt(u32, formula[num_start..i], 10);
        }

        // Store or add count
        const entry = try result.getOrPut(symbol);
        if (!entry.found_existing) {
            entry.value_ptr.* = count;
        } else {
            entry.value_ptr.* += count;
        }
    }

    return result;
}

/// Calculate molar mass from chemical formula
pub fn molarMass(allocator: std.mem.Allocator, formula: []const u8) !f64 {
    var counts = try parseFormula(allocator, formula);
    defer counts.deinit();

    var total: f64 = 0;
    var iter = counts.iterator();
    while (iter.next()) |entry| {
        const elem = getElement(entry.key_ptr.*) orelse return error.UnknownElement;
        total += @as(f64, @floatFromInt(entry.value_ptr.*)) * elem.mass;
    }
    return total;
}

/// Calculate percent composition of each element in formula
pub fn percentComposition(allocator: std.mem.Allocator, formula: []const u8) !std.StringHashMap(f64) {
    var counts = try parseFormula(allocator, formula);
    defer counts.deinit();

    const total_mass = try molarMass(allocator, formula);
    var result = std.StringHashMap(f64).init(allocator);

    var iter = counts.iterator();
    while (iter.next()) |entry| {
        const elem = getElement(entry.key_ptr.*) orelse return error.UnknownElement;
        const elem_mass = @as(f64, @floatFromInt(entry.value_ptr.*)) * elem.mass;
        const percent = (elem_mass / total_mass) * 100.0;
        try result.put(entry.key_ptr.*, percent);
    }
    return result;
}

// ═══════════════════════════════════════════════════════════════════════════════
// IDEAL GAS LAW: PV = nRT
// ═══════════════════════════════════════════════════════════════════════════════

pub fn idealGasLaw(p: ?f64, v: ?f64, n: ?f64, t: ?f64) struct { p: f64, v: f64, n: f64, t: f64 } {
    const P = p orelse 0;
    const V = v orelse 0;
    const N = n orelse 0;
    const T = t orelse 0;

    // PV = nRT → solve for missing variable
    if (P == 0) {
        // P = nRT/V
        return .{ .p = N * GAS_CONSTANT * T / V, .v = V, .n = N, .t = T };
    } else if (V == 0) {
        // V = nRT/P
        return .{ .p = P, .v = N * GAS_CONSTANT * T / P, .n = N, .t = T };
    } else if (N == 0) {
        // n = PV/RT
        return .{ .p = P, .v = V, .n = P * V / (GAS_CONSTANT * T), .t = T };
    } else {
        // T = PV/nR
        return .{ .p = P, .v = V, .n = N, .t = P * V / (N * GAS_CONSTANT) };
    }
}

/// Calculate pH from H+ concentration
pub fn calculatePH(h_conc: f64) f64 {
    return -std.math.log10(h_conc);
}

/// Calculate pOH from OH- concentration
pub fn calculatePOH(oh_conc: f64) f64 {
    return -std.math.log10(oh_conc);
}

/// pH + pOH = 14 (at 25°C)
pub fn phToPoh(ph: f64) f64 {
    return 14.0 - ph;
}

pub fn pohToPh(poh: f64) f64 {
    return 14.0 - poh;
}

/// Determine pH classification
pub fn phClassification(ph: f64) []const u8 {
    if (ph < 0) return "very acidic (below 0)";
    if (ph < 3) return "strongly acidic";
    if (ph < 6) return "weakly acidic";
    if (ph == 7.0) return "neutral";
    if (ph < 11) return "weakly basic";
    if (ph < 14) return "strongly basic";
    return "very basic (above 14)";
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM CHEMISTRY (Bohr Model)
// ═══════════════════════════════════════════════════════════════════════════════

pub const BOHR_RADIUS: f64 = sacred_const.physics.BOHR_RADIUS; // a_0 = 0.529 Å
pub const RYDBER: f64 = sacred_const.physics.RYDBER; // R_∞ = 1.097×10⁷ m⁻¹
pub const GROUND_STATE_H: f64 = -13.6; // eV (hydrogen ground state)

/// Bohr model energy level: E_n = -13.6 × Z²/n² eV
pub fn bohrEnergy(Z: u32, n: u32) f64 {
    return -13.6 * @as(f64, @floatFromInt(Z * Z)) / @as(f64, @floatFromInt(n * n));
}

/// Bohr radius for level n: r_n = a_0 × n²/Z
pub fn bohrRadius(Z: u32, n: u32) f64 {
    return BOHR_RADIUS * @as(f64, @floatFromInt(n * n)) / @as(f64, @floatFromInt(Z));
}

/// Hydrogen spectral line wavelength (nm)
/// 1/λ = R_∞ × (1/n_f² - 1/n_i²)
pub fn hydrogenWavelength(n_i: u32, n_f: u32) f64 {
    const inverse = RYDBER * (@as(f64, 1.0) / @as(f64, @floatFromInt(n_f * n_f)) - @as(f64, 1.0) / @as(f64, @floatFromInt(n_i * n_i)));
    return 1.0 / inverse; // in meters
}

/// Get series name for hydrogen transition
pub fn hydrogenSeries(n_final: u32) []const u8 {
    return switch (n_final) {
        1 => "Lyman (UV)",
        2 => "Balmer (visible)",
        3 => "Paschen (IR)",
        4 => "Brackett (IR)",
        5 => "Pfund (IR)",
        else => "high-order",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "getElement by symbol" {
    try std.testing.expectEqual(@as([]const u8, "Hydrogen"), getElement("H").?.name);
    try std.testing.expectEqual(@as([]const u8, "Gold"), getElement("Au").?.name);
    try std.testing.expectEqual(@as([]const u8, "Oxygen"), getElement("O").?.name);
}

test "getElement by number" {
    try std.testing.expectEqual(@as(u8, 1), getElement(@as(u8, 1)).?.number);
    try std.testing.expectEqual(@as(u8, 79), getElement(@as(u8, 79)).?.number);
    try std.testing.expectEqual(@as(u8, 118), getElement(@as(u8, 118)).?.number);
}

test "parseFormula simple" {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const result = try parseFormula(allocator, "H2O");
    defer result.deinit();

    try testing.expectEqual(@as(u32, 2), result.get("H").?);
    try testing.expectEqual(@as(u32, 1), result.get("O").?);
}

test "molarMass H2O" {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const mass = try molarMass(allocator, "H2O");
    try testing.expectApproxEqAbs(18.015, mass, 0.01);
}

test "molarMass CO2" {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const mass = try molarMass(allocator, "CO2");
    try testing.expectApproxEqAbs(44.009, mass, 0.01);
}

test "molarMass C6H12O6 (glucose)" {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    const mass = try molarMass(allocator, "C6H12O6");
    try testing.expectApproxEqAbs(180.156, mass, 0.01);
}

test "ideal gas law solve V" {
    const result = idealGasLaw(101325, 0, 1, 273.15); // p, v, n, t (v=0 to solve for it)
    try std.testing.expectApproxEqAbs(0.0224, result.v, 0.001); // ~22.4 L at STP
}

test "pH calculation" {
    try std.testing.expectApproxEqAbs(3.0, calculatePH(0.001), 0.01);
    try std.testing.expectApproxEqAbs(7.0, calculatePH(0.0000001), 0.01);
}

test "bohr energy" {
    try std.testing.expectApproxEqAbs(-13.6, bohrEnergy(1, 1), 0.1);
    try std.testing.expectApproxEqAbs(-3.4, bohrEnergy(1, 2), 0.1);
}

test "bohr radius" {
    try std.testing.expectApproxEqAbs(0.529, bohrRadius(1, 1), 0.01);
    try std.testing.expectApproxEqAbs(2.116, bohrRadius(1, 2), 0.01);
}

test "hydrogen wavelength Balmer alpha" {
    const lambda = hydrogenWavelength(3, 2); // H-alpha line
    try std.testing.expectApproxEqAbs(656.3e-9, lambda, 1e-12); // ~656 nm
}
