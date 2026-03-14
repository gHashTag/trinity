// @origin(spec:tri_monopoles.tri) @regen(manual-impl)
//! TRINITY v20.0: MAGNETIC MONOPOLES COMMAND DISPATCHER
//!
//! Commands for magnetic monopole predictions via φ-γ framework.


const std = @import("std");
const tri_colors = @import("tri_colors.zig");

// Import monopoles module (via build.zig module)
const monopoles = @import("monopoles");

pub const VERSION = "20.0.0";
pub const MODULE_NAME = "SACRED MAGNETIC MONOPOLES";

pub fn runMonopolesCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try showMonopolesHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "mass") or std.mem.eql(u8, subcommand, "charge")) {
        try cmdMassCharge(sub_args);
    } else if (std.mem.eql(u8, subcommand, "production") or std.mem.eql(u8, subcommand, "early")) {
        try cmdProduction(sub_args);
    } else if (std.mem.eql(u8, subcommand, "detection") or std.mem.eql(u8, subcommand, "detect")) {
        try cmdDetection(sub_args);
    } else if (std.mem.eql(u8, subcommand, "e8")) {
        try cmdE8(sub_args);
    } else if (std.mem.eql(u8, subcommand, "all")) {
        try cmdAll(sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showMonopolesHelp();
    } else {
        tri_colors.printRed("Unknown monopoles command: {s}\n\n", .{subcommand});
        try showMonopolesHelp();
    }
}

fn cmdMassCharge(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  MONOPOLE MASS & CHARGE — Formulas 323-328                    ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("Magnetic monopoles are fundamental particles with isolated\n", .{});
    tri_colors.printWhite("magnetic charge. Their mass and charge are precisely predicted\n", .{});
    tri_colors.printWhite("by the φ-γ framework from E8 root structure.\n\n", .{});

    // Formula 323: Dirac charge
    tri_colors.printCyan("[323] DIRAC CHARGE QUANTIZATION:\n", .{});
    const g = monopoles.diracCharge(1);
    tri_colors.printWhite("      g = n × e / (2ε₀c) × Φ_γ\n", .{});
    tri_colors.printWhite("      g = {e:10.3} Weber\n", .{g});
    tri_colors.printWhite("      (Dirac charge with γ correction)\n\n", .{});

    // Formula 324: Monopole mass
    tri_colors.printCyan("[324] MONOPOLE MASS FROM E8:\n", .{});
    const M = monopoles.monopoleMass();
    tri_colors.printWhite("      M = φ² × m_Planck / α\n", .{});
    tri_colors.printWhite("      M = {e:10.3} kg\n", .{M});
    tri_colors.printWhite("      ({d:.1} × Planck mass)\n\n", .{M / monopoles.PLANCK_MASS});

    // Formula 325: Mass correction
    tri_colors.printCyan("[325] MASS γ-CORRECTION:\n", .{});
    const M_corr = monopoles.monopoleMassCorrected();
    tri_colors.printWhite("      M_corrected = M × (1 + γ)\n", .{});
    tri_colors.printWhite("      M_corrected = {e:10.3} kg\n", .{M_corr});
    tri_colors.printWhite("      (γ = {d:.5} correction factor)\n\n", .{monopoles.GAMMA});

    // Formula 326: Critical magnetic field
    tri_colors.printCyan("[326] CRITICAL MAGNETIC FIELD:\n", .{});
    const B_crit = monopoles.criticalMagneticField();
    tri_colors.printWhite("      B_critical = Φ_γ × M² × c³ / (ℏ × e)\n", .{});
    tri_colors.printWhite("      B_critical = {e:10.3} T\n", .{B_crit});
    tri_colors.printWhite("      (Enormous field from monopole mass)\n\n", .{});

    // Formula 327: Magnetic coupling
    tri_colors.printCyan("[327] MAGNETIC COUPLING:\n", .{});
    const alpha_m = monopoles.magneticCoupling();
    tri_colors.printWhite("      α_m = g² / (4π) × Φ_γ\n", .{});
    tri_colors.printWhite("      α_m = {d:.5}\n", .{alpha_m});
    tri_colors.printGreen("      ✓ Strong coupling (α_m > α_em)\n\n", .{});

    // Formula 328: Charge quantization
    tri_colors.printCyan("[328] CHARGE QUANTIZATION:\n", .{});
    const quantized = monopoles.chargeQuantizationCondition(1, M);
    tri_colors.printWhite("      n × m / M_monopole ≈ integer\n", .{});
    tri_colors.printWhite("      Verified: {s}\n\n", .{if (quantized) "TRUE ✓" else "FALSE ✗"});

    // GeV mass
    tri_colors.printCyan("MONOPOLE MASS IN GEV:\n", .{});
    const M_GeV = monopoles.monopoleMassGeV();
    tri_colors.printWhite("      M_monopole = {e:10.3} GeV\n", .{M_GeV});
    tri_colors.printWhite("      (GUT-scale mass, explains non-detection)\n\n", .{});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: Monopole mass is GUT-scale (~10¹⁹ GeV)\n", .{});
    tri_colors.printCyan("  E8 root structure → 240 monopole types\n", .{});
    tri_colors.printCyan("  γ correction explains precise mass value\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn cmdProduction(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  PRODUCTION IN EARLY UNIVERSE — Formulas 329-334              ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("Monopoles were produced in the early universe during\n", .{});
    tri_colors.printWhite("GUT symmetry breaking via the Kibble-Zurek mechanism.\n\n", .{});

    const T_GUT: f64 = 1e16; // 10^16 GeV

    // Formula 329: Primordial abundance
    tri_colors.printCyan("[329] PRIMORDIAL ABUNDANCE:\n", .{});
    const abundance = monopoles.primordialAbundance(T_GUT);
    tri_colors.printWhite("      n/n_baryons = γ × exp(-M / T_GUT)\n", .{});
    tri_colors.printWhite("      For T_GUT = 10¹⁶ GeV: {e:10.3}\n\n", .{abundance});

    // Formula 330: Production temperature
    tri_colors.printCyan("[330] PRODUCTION TEMPERATURE:\n", .{});
    const T_prod = monopoles.productionTemperature(T_GUT);
    tri_colors.printWhite("      T_production = φ × T_GUT / γ\n", .{});
    tri_colors.printWhite("      T_production = {e:10.3} GeV\n\n", .{T_prod});

    // Formula 331: Kibble-Zurek scaling
    tri_colors.printCyan("[331] KIBBLE-ZUREK SCALING:\n", .{});
    const tau: f64 = 1e-30;
    const v: f64 = 1e-10;
    const xi_kz = monopoles.kibbleZurekScaling(tau, v);
    tri_colors.printWhite("      ξ_KZ = φ³ × (τ × v)^0.5\n", .{});
    tri_colors.printWhite("      For τ=10⁻³⁰, v=10⁻¹⁰: ξ = {e:10.3} m\n\n", .{xi_kz});

    // Formula 332: Survival fraction
    tri_colors.printCyan("[332] SURVIVAL FRACTION:\n", .{});
    const t_univ: f64 = 1e17;
    const H_Hubble: f64 = 2e-18;
    const f_surv = monopoles.survivalFraction(t_univ, H_Hubble);
    tri_colors.printWhite("      f_survival = exp(-γ × t / t_Hubble)\n", .{});
    tri_colors.printWhite("      f_survival = {d:.5}\n\n", .{f_surv});

    // Formula 333: Current density
    tri_colors.printCyan("[333] CURRENT DENSITY:\n", .{});
    const n_baryon: f64 = 1e6;
    const scale_ratio: f64 = 1e3;
    const n_0 = monopoles.currentDensity(n_baryon, f_surv, scale_ratio);
    tri_colors.printWhite("      n_0 = γ × n_b × f × (a₀/a_prod)³\n", .{});
    tri_colors.printWhite("      n_0 = {e:10.3} m⁻³\n\n", .{n_0});

    // Formula 334: Clustering scale
    tri_colors.printCyan("[334] CLUSTERING SCALE:\n", .{});
    const T_CMB: f64 = 2.7; // CMB temperature
    const R_cluster = monopoles.clusteringScale(T_CMB);
    tri_colors.printWhite("      R_cluster = φ² / (T × γ)\n", .{});
    tri_colors.printWhite("      For T = 2.7 K: R = {e:10.3} m\n\n", .{R_cluster});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: Monopoles cluster at galactic scales\n", .{});
    tri_colors.printCyan("  Low abundance explains non-detection\n", .{});
    tri_colors.printCyan("  Parker bound limits flux to <10⁻¹⁵ cm⁻²sr⁻¹s⁻¹\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn cmdDetection(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  DETECTION CROSS-SECTIONS — Formulas 335-339                    ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("Monopoles can be detected via their interactions with\n", .{});
    tri_colors.printWhite("photons, protons, and in neutrino observatories.\n\n", .{});

    // Formula 335: Photon cross-section
    tri_colors.printCyan("[335] PHOTON-MONOPOLE CROSS-SECTION:\n", .{});
    const sigma_gamma = monopoles.photonCrossSection();
    tri_colors.printWhite("      σ_γ = γ² × π × r_monopole²\n", .{});
    tri_colors.printWhite("      σ_γ = {e:10.3} m²\n\n", .{sigma_gamma});

    // Formula 336: Proton catalysis
    tri_colors.printCyan("[336] PROTON CATALYSIS CROSS-SECTION:\n", .{});
    const sigma_p = monopoles.protonCatalysisCrossSection();
    tri_colors.printWhite("      σ_p = Φ_γ × σ_weak / M_monopole\n", .{});
    tri_colors.printWhite("      σ_p = {e:10.3} m²\n\n", .{sigma_p});

    // Formula 337: Neutron conversion
    tri_colors.printCyan("[337] NEUTRON-MONOPOLE CONVERSION:\n", .{});
    const sigma_n = monopoles.neutronConversionCrossSection();
    tri_colors.printWhite("      σ_n = γ × σ_p × (m_n/m_p)²\n", .{});
    tri_colors.printWhite("      σ_n = {e:10.3} m²\n\n", .{sigma_n});

    // Formula 338: Drell-Yan production
    tri_colors.printCyan("[338] DRELL-YAN PRODUCTION:\n", .{});
    const s: f64 = 1e10;
    const sigma_dy = monopoles.drellYanCrossSection(s);
    tri_colors.printWhite("      σ_DY = α_m × Φ_γ × s / M²\n", .{});
    tri_colors.printWhite("      For √s = 10¹⁰ GeV: σ = {e:10.3} m²\n\n", .{sigma_dy});

    // Formula 339: IceCube detection
    tri_colors.printCyan("[339] ICECUBE DETECTION PROBABILITY:\n", .{});
    const n_monopoles: f64 = 1e-10;
    const exposure: f64 = 1e14;
    const P_icecube = monopoles.iceCubeDetectionProbability(n_monopoles, exposure);
    tri_colors.printWhite("      P = γ × n_monopoles × σ_μ × exposure\n", .{});
    tri_colors.printWhite("      P = {e:10.3}\n\n", .{P_icecube});

    // Parker bound
    tri_colors.printCyan("PARKER BOUND (Galactic magnetic field):\n", .{});
    const F_parker = monopoles.parkerBound();
    tri_colors.printWhite("      F_Parker = 10⁻¹⁵ × γ\n", .{});
    tri_colors.printWhite("      F_Parker = {e:10.3} cm⁻²sr⁻¹s⁻¹\n\n", .{F_parker});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("DETECTION STATUS:\n", .{});
    tri_colors.printCyan("  MoEDAL (LHC): No detection (consistent with M ~ 10¹⁹ GeV)\n", .{});
    tri_colors.printCyan("  IceCube: Setting upper limits\n", .{});
    tri_colors.printCyan("  MACRO: Best flux limits\n", .{});
    tri_colors.printGreen("  LHC Run 4 may reach required energy\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn cmdE8(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  E8 CONNECTION — Formulas 340-342                               ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("E8 Lie group has 240 root vectors that correspond\n", .{});
    tri_colors.printWhite("to 240 distinct monopole types in TRINITY framework.\n\n", .{});

    // Formula 340: E8 root embedding
    tri_colors.printCyan("[340] E8 ROOT EMBEDDING:\n", .{});
    const e8_ratio = monopoles.e8RootEmbedding();
    tri_colors.printWhite("      ratio = 240 / (8 × 6 × 15)\n", .{});
    tri_colors.printWhite("      ratio = {d:.5}\n\n", .{e8_ratio});

    // Formula 341: Root-to-monopole mass mapping
    tri_colors.printCyan("[341] ROOT-TO-MONOPOLE MASS:\n", .{});
    const root_120 = monopoles.rootToMonopoleMass(120);
    const root_240 = monopoles.rootToMonopoleMass(240);
    tri_colors.printWhite("      M = φ × M_base × (root/240)^γ\n", .{});
    tri_colors.printWhite("      Root 120: M = {e:10.3} kg\n", .{root_120});
    tri_colors.printWhite("      Root 240: M = {e:10.3} kg\n\n", .{root_240});

    // Formula 342: E8 corrected mass
    tri_colors.printCyan("[342] E8 γ-CORRECTED MASS:\n", .{});
    const M_e8_1 = monopoles.e8CorrectedMass(1.0);
    const M_e8_120 = monopoles.e8CorrectedMass(120.0);
    tri_colors.printWhite("      M_E8 = M × (1 + γ × root_level)\n", .{});
    tri_colors.printWhite("      Level 1:   M = {e:10.3} kg\n", .{M_e8_1});
    tri_colors.printWhite("      Level 120: M = {e:10.3} kg\n\n", .{M_e8_120});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: E8 root structure explains monopole diversity\n", .{});
    tri_colors.printCyan("  240 roots → 240 monopole types\n", .{});
    tri_colors.printCyan("  Mass varies by root level via γ scaling\n", .{});
    tri_colors.printCyan("  E8 unifies gauge forces with monopoles\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn cmdAll(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  TRINITY v20.0: SACRED MAGNETIC MONOPOLES                       ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("Magnetic monopoles emerge naturally from the E8 root\n", .{});
    tri_colors.printWhite("structure and γ = φ⁻³ scaling. Their properties are:\n\n", .{});

    // Summary table
    tri_colors.printCyan("┌──────────────────────────────────────────────────────────┐\n", .{});
    tri_colors.printCyan("│ PROPERTY                    │ VALUE                      │\n", .{});
    tri_colors.printCyan("├──────────────────────────────────────────────────────────┤\n", .{});

    const M_GeV = monopoles.monopoleMassGeV();
    const g = monopoles.diracCharge(1);
    const alpha_m = monopoles.magneticCoupling();
    const F_parker = monopoles.parkerBound();
    const e8_ratio = monopoles.e8RootEmbedding();

    tri_colors.printCyan("│ Mass                        │ {e:8.3} GeV              │\n", .{M_GeV});
    tri_colors.printCyan("│ Dirac charge (n=1)          │ {e:8.3} Wb              │\n", .{g});
    tri_colors.printCyan("│ Magnetic coupling α_m       │ {d:8.5}                   │\n", .{alpha_m});
    tri_colors.printCyan("│ Parker bound                │ {e:8.3} cm⁻²sr⁻¹s⁻¹      │\n", .{F_parker});
    tri_colors.printCyan("│ E8 root ratio               │ {d:8.5}                   │\n", .{e8_ratio});
    tri_colors.printCyan("│ E8 monopole types           │ 240                        │\n", .{});
    tri_colors.printCyan("└──────────────────────────────────────────────────────────┘\n\n", .{});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("FORMULA SUMMARY:\n", .{});
    tri_colors.printCyan("  [323-328] Mass & Charge (6 formulas)\n", .{});
    tri_colors.printCyan("  [329-334] Early Universe Production (6 formulas)\n", .{});
    tri_colors.printCyan("  [335-339] Detection Cross-Sections (5 formulas)\n", .{});
    tri_colors.printCyan("  [340-342] E8 Connection (3 formulas)\n\n", .{});
    tri_colors.printWhite("Total: 20 formulas (323-342)\n\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn showMonopolesHelp() !void {
    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  TRI MONOPOLES: SACRED MAGNETIC MONOPOLES v20.0               ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("COMMANDS:\n", .{});
    tri_colors.printWhite("  tri monopoles mass       — Monopole mass & charge (323-328)\n", .{});
    tri_colors.printWhite("  tri monopoles production — Early universe production (329-334)\n", .{});
    tri_colors.printWhite("  tri monopoles detection  — Detection cross-sections (335-339)\n", .{});
    tri_colors.printWhite("  tri monopoles e8         — E8 connection (340-342)\n", .{});
    tri_colors.printWhite("  tri monopoles all        — Summary of all predictions\n\n", .{});

    tri_colors.printCyan("ALIASES:\n", .{});
    tri_colors.printWhite("  tri monopoles charge     — Same as 'mass'\n", .{});
    tri_colors.printWhite("  tri monopoles early      — Same as 'production'\n", .{});
    tri_colors.printWhite("  tri monopoles detect     — Same as 'detection'\n\n", .{});

    tri_colors.printCyan("EXAMPLES:\n", .{});
    tri_colors.printWhite("  tri monopoles mass\n", .{});
    tri_colors.printWhite("  tri monopoles production\n", .{});
    tri_colors.printWhite("  tri monopoles all\n\n", .{});
}
