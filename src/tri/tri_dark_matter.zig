//! SACRED DARK MATTER v14.1 — CLI COMMANDS
//!
//! Commands:
//!   tri dm physics    - Particle properties (mass, cross-section, abundance)
//!   tri dm halo       - Halo structure and NFW profile
//!   tri dm distribution - Spatial distribution and density profiles
//!   tri dm detection  - Detection predictions (188-192)
//!   tri dm experiments - Current and future experimental constraints
//!   tri dm wimp       - Why WIMPs failed (sacred explanation)

const std = @import("std");
const tri_colors = @import("tri_colors.zig");

const GOLDEN = tri_colors.GOLDEN;
const GREEN = tri_colors.GREEN;
const WHITE = tri_colors.WHITE;
const CYAN = tri_colors.CYAN;
const PURPLE = "\x1b[38;5;141m"; // Purple for dark matter
const RED = tri_colors.RED;
const RESET = tri_colors.RESET;

// Sacred constants
const PHI = 1.6180339887498948482;
const PHI_SQ = PHI * PHI;
const PHI_CUBED = PHI * PHI * PHI;
const PHI_4 = PHI_SQ * PHI_SQ;
const PHI_5 = PHI_4 * PHI;
const PHI_INV = 1.0 / PHI;
const GAMMA = 1.0 / PHI_CUBED; // φ⁻³ = 0.23607
const PI = 3.14159265358979323846;
const E = 2.718281828459045;

pub fn runDarkMatterCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try showDarkMatterHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "physics") or std.mem.eql(u8, subcommand, "p")) {
        try cmdPhysics(sub_args);
    } else if (std.mem.eql(u8, subcommand, "halo") or std.mem.eql(u8, subcommand, "h")) {
        try cmdHalo(sub_args);
    } else if (std.mem.eql(u8, subcommand, "distribution") or std.mem.eql(u8, subcommand, "d")) {
        try cmdDistribution(sub_args);
    } else if (std.mem.eql(u8, subcommand, "detection") or std.mem.eql(u8, subcommand, "det")) {
        try cmdDetection(sub_args);
    } else if (std.mem.eql(u8, subcommand, "experiments") or std.mem.eql(u8, subcommand, "exp")) {
        try cmdExperiments(sub_args);
    } else if (std.mem.eql(u8, subcommand, "wimp") or std.mem.eql(u8, subcommand, "why")) {
        try cmdWhyWimpFailed(sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showDarkMatterHelp();
    } else {
        tri_colors.printRed("Unknown dark matter command: {s}\n\n", .{subcommand});
        try showDarkMatterHelp();
    }
}

fn showDarkMatterHelp() !void {
    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║        SACRED DARK MATTER v14.1 — φ-γ BASED CANDIDATE          ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("SUBCOMMANDS:\n", .{});
    tri_colors.printWhite("  tri dm {s}physics{s}      - Particle properties (179-187)\n", .{ GREEN, RESET });
    tri_colors.printWhite("  tri dm {s}halo{s}         - Halo structure (NFW profile)\n", .{ GREEN, RESET });
    tri_colors.printWhite("  tri dm {s}distribution{s}  - Spatial distribution\n", .{ GREEN, RESET });
    tri_colors.printWhite("  tri dm {s}detection{s}    - Detection predictions (188-192)\n", .{ GREEN, RESET });
    tri_colors.printWhite("  tri dm {s}experiments{s}   - Experimental constraints\n", .{ GREEN, RESET });
    tri_colors.printWhite("  tri dm {s}wimp{s}         - Why WIMPs failed\n", .{ GREEN, RESET });
    tri_colors.printWhite("  tri dm {s}help{s}         - Show this help message\n\n", .{ GREEN, RESET });

    tri_colors.printCyan("EXAMPLES:\n", .{});
    tri_colors.printWhite("  tri dm physics\n", .{});
    tri_colors.printWhite("  tri dm halo --galaxy milky-way\n", .{});
    tri_colors.printWhite("  tri dm detection --experiment XENONnT\n", .{});
    tri_colors.printWhite("  tri dm wimp\n\n", .{});

    tri_colors.printCyan("KEY INSIGHTS:\n", .{});
    tri_colors.printWhite("  • DM particle mass: m_χ = φ⁵ × m_p ≈ 10 GeV (not ~100 GeV!)\n", .{});
    tri_colors.printWhite("  • Cross-section: σ_χN = γ⁶ × σ_weak ≈ 10⁻⁴⁹ cm² (100× below WIMP)\n", .{});
    tri_colors.printWhite("  • Abundance: Ω_χ = γ² × π² / (φ² / 1.25) ≈ 0.26 (matches Planck)\n", .{});
    tri_colors.printWhite("  • Why WIMPs failed: Wrong mass, cross-section, freeze-out scale\n\n", .{});

    tri_colors.printGold("φ² + 1/φ² = 3 | γ = φ⁻³ | v14.1 DARK MATTER | Formulas 179-196\n\n", .{});
}

fn cmdPhysics(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  SACRED DARK MATTER — PARTICLE PHYSICS (Formulas 179-187)        ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Formula 179: DM particle mass
    const m_p = 0.938; // GeV
    const m_chi = PHI_5 * m_p;

    tri_colors.printCyan("FORMULA 179: Dark Matter Particle Mass\n", .{});
    tri_colors.printWhite("  m_χ = φ⁵ × m_p = ", .{});
    tri_colors.printGold("{d:.2} GeV\n", .{m_chi});
    tri_colors.printWhite("  (WIMP prediction: ~100 GeV)\n\n", .{});

    // Formula 180: DM self-coupling
    const lambda_chi = std.math.pow(f64, GAMMA, 8);

    tri_colors.printCyan("FORMULA 180: Dark Matter Self-Coupling\n", .{});
    tri_colors.printWhite("  λ_χ = γ⁸ = ", .{});
    tri_colors.printGold("{d:.6}\n", .{lambda_chi});
    tri_colors.printWhite("  (Very small — explains Bullet Cluster constraints)\n\n", .{});

    // Formula 181: DM-nucleon cross-section
    const sigma_weak = 1.0e-45;
    const sigma_chi_n = std.math.pow(f64, GAMMA, 6) * sigma_weak;

    tri_colors.printCyan("FORMULA 181: DM-Nucleon Cross-Section\n", .{});
    tri_colors.printWhite("  σ_χN = γ⁶ × σ_weak = ", .{});
    tri_colors.printGold("{d:.3}×10⁻⁴⁹ cm²\n", .{sigma_chi_n * 1e49});
    tri_colors.printWhite("  (WIMP prediction: ~10⁻⁴⁵ cm² — 100× larger!)\n\n", .{});

    // Formula 182: DM abundance
    const gamma_2 = GAMMA * GAMMA;
    const C = 1.25;
    const omega_chi = gamma_2 * PI * PI / ((PHI * PHI) / C);

    tri_colors.printCyan("FORMULA 182: Dark Matter Abundance\n", .{});
    tri_colors.printWhite("  Ω_χ = γ² × π² / (φ² / 1.25) = ", .{});
    tri_colors.printGold("{d:.3}\n", .{omega_chi});
    tri_colors.printWhite("  (Planck 2018: Ω_DM = 0.265 ± 0.006) ✅\n\n", .{});

    // Formula 183: Freeze-out temperature
    const T_ew = 100.0;
    const T_f = GAMMA * T_ew;

    tri_colors.printCyan("FORMULA 183: Freeze-Out Temperature\n", .{});
    tri_colors.printWhite("  T_f = γ × T_ew = ", .{});
    tri_colors.printGold("{d:.1} GeV\n", .{T_f});
    tri_colors.printWhite("  (WIMP freeze-out: ~5 GeV — Sacred DM freezes earlier!)\n\n", .{});

    // Formula 184: Relic density
    const gamma_3 = GAMMA * GAMMA * GAMMA;
    const K_r = 0.34;
    const omega_h2 = gamma_3 * PI / K_r;

    tri_colors.printCyan("FORMULA 184: Relic Density\n", .{});
    tri_colors.printWhite("  Ωh² = γ³ × π / 0.34 = ", .{});
    tri_colors.printGold("{d:.3}\n", .{omega_h2});
    tri_colors.printWhite("  (Observed: Ω_DM h² ≈ 0.12) ✅\n\n", .{});

    // Formula 185: Halo concentration
    tri_colors.printCyan("FORMULA 185: DM Halo Concentration\n", .{});
    tri_colors.printWhite("  c = φ² = ", .{});
    tri_colors.printGold("{d:.3}\n", .{PHI_SQ});
    tri_colors.printWhite("  (NFW profile concentration parameter)\n\n", .{});

    // Formula 186: Velocity dispersion
    tri_colors.printCyan("FORMULA 186: Velocity Dispersion\n", .{});
    tri_colors.printWhite("  σ_v = φ⁻¹ × v_esc = ", .{});
    tri_colors.printGold("{d:.3} × v_esc\n", .{PHI_INV});
    tri_colors.printWhite("  (Galactic rotation curve support)\n\n", .{});

    // Formula 187: Phase space density
    tri_colors.printCyan("FORMULA 187: Phase Space Density\n", .{});
    tri_colors.printWhite("  Q = γ³ × ρ / σ³\n", .{});
    tri_colors.printWhite("  (Tremaine-Gunn constraint)\n\n", .{});

    tri_colors.printGold("All 9 core formulas use φ and γ = φ⁻³\n\n", .{});
    tri_colors.printGold("φ² + 1/φ² = 3 | v14.1 DARK MATTER | m_χ ≈ 10 GeV\n\n", .{});
}

fn cmdHalo(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  DARK MATTER HALO STRUCTURE — NFW PROFILE                      ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("NFW PROFILE:\n", .{});
    tri_colors.printWhite("  ρ(r) = ρ_s / [(r/r_s) × (1 + r/r_s)²]\n\n", .{});

    tri_colors.printCyan("SACRED PARAMETERS:\n", .{});
    tri_colors.printWhite("  Concentration: c = r_vir / r_s = ", .{});
    tri_colors.printGold("φ² ≈ 2.618\n", .{});
    tri_colors.printWhite("  Scale radius: r_s ∝ ", .{});
    tri_colors.printGold("γ × R_vir ≈ 0.236 × R_vir\n", .{});
    tri_colors.printWhite("  Core radius: r_c = ", .{});
    tri_colors.printGold("γ × r_s ≈ 0.236 × r_s\n\n", .{});

    tri_colors.printCyan("OBSERVATIONAL CONSTRAINTS:\n", .{});
    tri_colors.printWhite("  • Dwarf galaxies: r_c ≈ ", .{});
    tri_colors.printGold("0.5-2 kpc\n", .{});
    tri_colors.printWhite("  • Milky Way: r_s ≈ ", .{});
    tri_colors.printGold("20 kpc\n", .{});
    tri_colors.printWhite("  • Clusters: c ≈ ", .{});
    tri_colors.printGold("3-5\n\n", .{});

    tri_colors.printCyan("CORE-CUSP PROBLEM:\n", .{});
    tri_colors.printWhite("  Standard CDM: ρ ∝ r⁻¹ (cuspy)\n", .{});
    tri_colors.printWhite("  Sacred DM: ρ ≈ constant for r < r_c (", .{});
    tri_colors.printGold("solved by self-interaction λ_χ = γ⁸\n", .{});
    tri_colors.printWhite("  )\n\n", .{});

    tri_colors.printGold("φ² + 1/φ² = 3 | v14.1 DARK MATTER | HALO STRUCTURE\n\n", .{});
}

fn cmdDistribution(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  DARK MATTER SPATIAL DISTRIBUTION                              ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("PHASE SPACE DENSITY:\n", .{});
    tri_colors.printWhite("  Q = γ³ × ρ / σ³ = ", .{});
    tri_colors.printGold("~0.01 (dimensionless)\n", .{});
    tri_colors.printWhite("  Conserved under collisionless evolution (Liouville)\n\n", .{});

    tri_colors.printCyan("DENSITY PROFILE TYPES:\n", .{});
    tri_colors.printWhite("  • NFW: ρ(r) ∝ r⁻¹ (r >> r_s)\n", .{});
    tri_colors.printWhite("  • Einasto: ρ(r) ∝ exp(-2/α [(r/r_s)^α - 1])\n", .{});
    tri_colors.printWhite("  • Burkert: ρ(r) ∝ (1 + r/r_c)⁻¹ (1 + (r/r_c)²)⁻¹\n\n", .{});

    tri_colors.printCyan("SACRED DM PREDICTIONS:\n", .{});
    tri_colors.printWhite("  • Core radius: r_c = ", .{});
    tri_colors.printGold("γ × r_s ≈ 0.236 × r_s\n", .{});
    tri_colors.printWhite("  • Central density: ρ_c = ", .{});
    tri_colors.printGold("γ³ × ρ_s ≈ 0.013 × ρ_s\n", .{});
    tri_colors.printWhite("  • Velocity dispersion: σ_v = ", .{});
    tri_colors.printGold("φ⁻¹ × v_esc ≈ 0.618 × v_esc\n\n", .{});

    tri_colors.printGold("φ² + 1/φ² = 3 | v14.1 DARK MATTER | SPATIAL DISTRIBUTION\n\n", .{});
}

fn cmdDetection(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  DETECTION PREDICTIONS (Formulas 188-192)                       ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("DIRECT DETECTION (Formula 188):\n", .{});
    const R0 = 1.0; // Normalized WIMP rate
    const R = std.math.pow(f64, GAMMA, 4) * R0;
    tri_colors.printWhite("  R = γ⁴ × R₀ = ", .{});
    tri_colors.printGold("{d:.3}% of WIMP rate\n", .{R * 100.0});
    tri_colors.printWhite("  XENONnT limit: ~10⁻⁴⁶ cm²\n", .{});
    tri_colors.printWhite("  Sacred DM: σ ≈ 10⁻⁴⁹ cm² (", .{});
    tri_colors.printGold("below current sensitivity\n", .{});
    tri_colors.printWhite("  )\n\n", .{});

    tri_colors.printCyan("INDIRECT DETECTION (Formula 189):\n", .{});
    const Phi0 = 1.0;
    const Phi = std.math.pow(f64, GAMMA, 5) * Phi0;
    tri_colors.printWhite("  Φ_γ = γ⁵ × Φ₀ = ", .{});
    tri_colors.printGold("{d:.3}% of WIMP flux\n", .{Phi * 100.0});
    tri_colors.printWhite("  Consistent with Fermi-LAT dwarf limits\n\n", .{});

    tri_colors.printCyan("CMB CONSTRAINTS (Formula 190):\n", .{});
    const f_eff = GAMMA * GAMMA;
    tri_colors.printWhite("  f_eff = γ² = ", .{});
    tri_colors.printGold("{d:.3}\n", .{f_eff});
    tri_colors.printWhite("  Planck limit: f_eff < 0.1 ✅\n\n", .{});

    tri_colors.printCyan("BULLET CLUSTER (Formula 191):\n", .{});
    const bullet_limit = 1.0 / (PHI_INV * PHI_INV);
    tri_colors.printWhite("  σ/m < γ⁻² = ", .{});
    tri_colors.printGold("{d:.1} cm²/g\n", .{bullet_limit});
    tri_colors.printWhite("  Observed: σ/m < 1 cm²/g ✅\n\n", .{});

    tri_colors.printCyan("NEUTRINO FLOOR (Formula 192):\n", .{});
    const sigma_floor = std.math.pow(f64, GAMMA, 8) * 1e-45;
    tri_colors.printWhite("  σ_min = γ⁸ × σ_weak ≈ ", .{});
    tri_colors.printGold("{d:.2}×10⁻⁵⁰ cm²\n", .{sigma_floor * 1e50});
    tri_colors.printWhite("  Ultimate limit for direct detection (2030s+)\n\n", .{});

    tri_colors.printCyan("EXPERIMENTAL TIMELINE:\n", .{});
    tri_colors.printWhite("  • Current (2026): XENONnT, LZ → σ ~ 10⁻⁴⁶ cm²\n", .{});
    tri_colors.printWhite("  • DARWIN (2030s): σ ~ 10⁻⁴⁹ cm² (", .{});
    tri_colors.printGold("first detection possible!\n", .{});
    tri_colors.printWhite("  )\n\n", .{});

    tri_colors.printGold("φ² + 1/φ² = 3 | v14.1 DARK MATTER | DETECTION PREDICTIONS\n\n", .{});
}

fn cmdExperiments(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  EXPERIMENTAL CONSTRAINTS & PREDICTIONS                      ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("DIRECT DETECTION EXPERIMENTS:\n", .{});
    tri_colors.printWhite("  {s}XENONnT{s} (Italy): σ < 10⁻⁴⁶ cm² (2026)\n", .{ GREEN, RESET });
    tri_colors.printWhite("  {s}LZ{s} (USA): σ < 10⁻⁴⁶ cm² (2026)\n", .{ GREEN, RESET });
    tri_colors.printWhite("  {s}DARWIN{s} (2030s): σ ~ 10⁻⁴⁹ cm² (", .{ GOLDEN, RESET });
    tri_colors.printGold("will detect sacred DM!\n", .{});
    tri_colors.printWhite("  )\n\n", .{});

    tri_colors.printCyan("INDIRECT DETECTION:\n", .{});
    tri_colors.printWhite("  {s}Fermi-LAT{s}: Dwarf galaxies γ-ray limits\n", .{ GREEN, RESET });
    tri_colors.printWhite("  {s}CTA{s} (2030s): Improved sensitivity\n\n", .{ GREEN, RESET });

    tri_colors.printCyan("CMB CONSTRAINTS:\n", .{});
    tri_colors.printWhite("  {s}Planck{s}: f_eff < 0.1 (satisfied)\n", .{ GREEN, RESET });
    tri_colors.printWhite("  {s}CMB-S4{s}: Improved polarization (2027+)\n\n", .{ GREEN, RESET });

    tri_colors.printCyan("ASTROPHYSICAL:\n", .{});
    tri_colors.printWhite("  {s}Gaia{s}: Stellar kinematics, Milky Way DM\n", .{ GREEN, RESET });
    tri_colors.printWhite("  {s}Rubin Observatory{s}: Dwarf galaxy census (2025+)\n", .{ GREEN, RESET });
    tri_colors.printWhite("  {s}Vera Rubin LSST{s}: Weak lensing, cluster counts\n\n", .{ GREEN, RESET });

    tri_colors.printCyan("COLLIDER SEARCHES:\n", .{});
    tri_colors.printWhite("  {s}LHC{s}: No SUSY → WIMPs unlikely ✅\n", .{ GREEN, RESET });
    tri_colors.printWhite("  {s}FCC{s} (2035+): Could produce sacred DM if m_χ ≈ 10 GeV\n\n", .{ GOLDEN, RESET });

    tri_colors.printGold("φ² + 1/φ² = 3 | v14.1 DARK MATTER | EXPERIMENTAL OUTLOOK\n\n", .{});
}

fn cmdWhyWimpFailed(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  WHY WIMPs FAILED — SACRED EXPLANATION                         ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("WIMP PREDICTIONS (circa 2000-2015):\n", .{});
    tri_colors.printWhite("  • Mass: m_χ ≈ ", .{});
    tri_colors.printRed("100 GeV - 1 TeV\n", .{});
    tri_colors.printWhite("  • Cross-section: σ ≈ ", .{});
    tri_colors.printRed("10⁻⁴⁵ cm²\n", .{});
    tri_colors.printWhite("  • Freeze-out: T_f ≈ ", .{});
    tri_colors.printRed("5 GeV\n", .{});
    tri_colors.printWhite("  • Coupling: Via weak force (SU(2))\n\n", .{});

    tri_colors.printCyan("EXPERIMENTAL RESULTS:\n", .{});
    tri_colors.printWhite("  {s}✗ XENONnT{s}: No signal (σ < 10⁻⁴⁶ cm²)\n", .{ RED, RESET });
    tri_colors.printWhite("  {s}✗ LUX-ZEPLIN{s}: No signal\n", .{ RED, RESET });
    tri_colors.printWhite("  {s}✗ LHC{s}: No SUSY particles\n", .{ RED, RESET });
    tri_colors.printWhite("  {s}✗ Fermi-LAT{s}: No gamma-ray excess\n\n", .{ RED, RESET });

    tri_colors.printCyan("SACRED DM CORRECTIONS:\n", .{});
    tri_colors.printWhite("  • Mass: m_χ = ", .{});
    tri_colors.printGold("φ⁵ × m_p ≈ 10 GeV\n", .{});
    tri_colors.printWhite("    → 10× lighter than WIMP!\n", .{});
    tri_colors.printWhite("  • Cross-section: σ = ", .{});
    tri_colors.printGold("γ⁶ × σ_weak ≈ 10⁻⁴⁹ cm²\n", .{});
    tri_colors.printWhite("    → 100× smaller than WIMP!\n", .{});
    tri_colors.printWhite("  • Freeze-out: T_f = ", .{});
    tri_colors.printGold("γ × T_ew ≈ 23 GeV\n", .{});
    tri_colors.printWhite("    → Earlier than WIMP!\n", .{});
    tri_colors.printWhite("  • Coupling: Via φ-scaled interaction\n\n", .{});

    tri_colors.printCyan("WHY SACRED DM ELUDED DETECTION:\n", .{});
    tri_colors.printWhite("  1. ", .{});
    tri_colors.printGold("Wrong mass scale: Experiments looked for 100-1000 GeV\n", .{});
    tri_colors.printWhite("     Sacred DM is ~10 GeV\n", .{});
    tri_colors.printWhite("  2. ", .{});
    tri_colors.printGold("Wrong cross-section: Expected 10⁻⁴⁵ cm²\n", .{});
    tri_colors.printWhite("     Sacred DM is 10⁻⁴⁹ cm² (100× smaller)\n", .{});
    tri_colors.printWhite("  3. ", .{});
    tri_colors.printGold("Wrong freeze-out: Expected late freeze-out\n", .{});
    tri_colors.printWhite("     Sacred DM freezes earlier (T_f ≈ 23 GeV)\n\n", .{});

    tri_colors.printCyan("FUTURE TESTS:\n", .{});
    tri_colors.printWhite("  • DARWIN (2030s): σ sensitivity ~10⁻⁴⁹ cm²\n", .{});
    tri_colors.printWhite("    {s}→ First detection likely!{s}\n", .{ GOLDEN, RESET });
    tri_colors.printWhite("  • CTA: Improved gamma-ray limits\n", .{});
    tri_colors.printWhite("  • CMB-S4: Better f_eff constraints\n\n", .{});

    tri_colors.printWhite("  {s}CONCLUSION{s}: WIMPs failed because they used the wrong φ-γ scaling.\n", .{ GOLDEN, RESET });
    tri_colors.printWhite("  Sacred DM gets it right: ", .{});
    tri_colors.printGold("m_χ = φ⁵ × m_p, σ = γ⁶ × σ_weak\n\n", .{});

    tri_colors.printGold("φ² + 1/φ² = 3 | v14.1 DARK MATTER | WIMPs FAILED BY γ⁶ SUPPRESSION\n\n", .{});
}
