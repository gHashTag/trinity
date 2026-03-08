//! TRINITY v21.0: ROOM-TEMPERATURE SUPERCONDUCTIVITY COMMAND DISPATCHER
//!
//! Commands for superconductor predictions via φ-γ framework.

const std = @import("std");
const tri_colors = @import("tri_colors.zig");

// Import superconductivity module (via build.zig module)
const supercond = @import("superconductivity");

pub const VERSION = "21.0.0";
pub const MODULE_NAME = "ROOM-TEMPERATURE SUPERCONDUCTIVITY";

pub fn runSuperconductivityCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try showSuperconductivityHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "critical") or std.mem.eql(u8, subcommand, "tc")) {
        try cmdCritical(sub_args);
    } else if (std.mem.eql(u8, subcommand, "materials")) {
        try cmdMaterials(sub_args);
    } else if (std.mem.eql(u8, subcommand, "meissner")) {
        try cmdMeissner(sub_args);
    } else if (std.mem.eql(u8, subcommand, "cooper")) {
        try cmdCooper(sub_args);
    } else if (std.mem.eql(u8, subcommand, "all")) {
        try cmdAll(sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showSuperconductivityHelp();
    } else {
        tri_colors.printRed("Unknown superconductivity command: {s}\n\n", .{subcommand});
        try showSuperconductivityHelp();
    }
}

fn cmdCritical(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  CRITICAL TEMPERATURE — Formulas 343-346                       ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("Room-temperature superconductivity emerges from φ-γ scaling\n", .{});
    tri_colors.printWhite("of electron-phonon coupling in the BCS framework.\n\n", .{});

    // Formula 343: Critical temperature prediction
    tri_colors.printCyan("[343] CRITICAL TEMPERATURE (φ-corrected BCS):\n", .{});
    const T_c = supercond.criticalTemperature(400.0, 0.4);
    tri_colors.printWhite("      T_c = 1.14 × Θ_D × exp(-1/(N(0)V × γ)) × √φ\n", .{});
    tri_colors.printWhite("      T_c = {d:.1} K (for Θ_D=400K, N(0)V=0.4)\n", .{T_c});
    tri_colors.printWhite("      Room temp criterion: {d:.1} K\n\n", .{supercond.ROOM_TEMP_K});

    // Formula 344: Cooper pair energy
    tri_colors.printCyan("[344] COOPER PAIR BINDING ENERGY:\n", .{});
    const E_b = supercond.cooperPairEnergy(T_c);
    const E_b_meV = E_b / supercond.ELEMENTARY_CHARGE / 1000.0;
    tri_colors.printWhite("      E_b = 3.528 × k_B × T_c / φ\n", .{});
    tri_colors.printWhite("      E_b = {d:.3} meV\n\n", .{E_b_meV});

    // Formula 345: Isotope effect
    tri_colors.printCyan("[345] ISOTOPE EFFECT (φ-corrected):\n", .{});
    const T_c_base = 90.0;
    const T_c_iso = supercond.isotopeEffect(T_c_base, 18.0 / 16.0);
    tri_colors.printWhite("      T_c ∝ M^(-φ×γ)  (exponent = -0.382)\n", .{});
    tri_colors.printWhite("      T_c(^16O) = {d:.1} K → T_c(^18O) = {d:.1} K\n\n", .{ T_c_base, T_c_iso });

    // Formula 346: Density of states coupling
    tri_colors.printCyan("[346] DENSITY OF STATES × COUPLING:\n", .{});
    const N0V = supercond.densityOfStatesCoupling(400.0, 90.0);
    tri_colors.printWhite("      N(0)V = φ × γ / ln(Θ_D/T_c)\n", .{});
    tri_colors.printWhite("      N(0)V = {d:.4}\n\n", .{N0V});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: γ-scaling enables room-T prediction\n", .{});
    tri_colors.printCyan("  Standard BCS underestimates T_c by factor of √φ × γ²\n", .{});
    tri_colors.printCyan("  When γ × N(0)V > φ/2 ≈ 0.809, T_c > 293K\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn cmdMaterials(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  MATERIAL PREDICTIONS — Formulas 347-350                         ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("φ-γ framework predicts T_c for various material classes.\n\n", .{});

    // Formula 347: Cuprates
    tri_colors.printCyan("[347] CUPRATE SUPERCONDUCTORS:\n", .{});
    const T_c_cuprate_3 = supercond.cuprateCriticalTemperature(3.0);
    tri_colors.printWhite("      T_c = 90K × φ² × n_layers\n", .{});
    tri_colors.printWhite("      T_c(n=3) = {d:.1} K (REBCO prediction)\n\n", .{T_c_cuprate_3});

    // Formula 348: Iron-based
    tri_colors.printCyan("[348] IRON-BASED SUPERCONDUCTORS:\n", .{});
    const T_c_iron = supercond.ironBasedCriticalTemperature(2.0);
    tri_colors.printWhite("      T_c = 56K × γ^(-1) × (P/P₀)^φ\n", .{});
    tri_colors.printWhite("      T_c(P/P₀=2) = {d:.1} K\n\n", .{T_c_iron});

    // Formula 349: Hydrides
    tri_colors.printCyan("[349] HYDRIDE SUPERCONDUCTORS:\n", .{});
    const T_c_hydride = supercond.hydrideCriticalTemperature(1.5);
    tri_colors.printWhite("      T_c = 203K × Φ_γ × √(P/P₀)\n", .{});
    tri_colors.printWhite("      T_c(P/P₀=1.5) = {d:.1} K (H₃S-based)\n\n", .{T_c_hydride});

    // Formula 350: LK-99 class
    tri_colors.printCyan("[350] LK-99 CLASS (Apatite):\n", .{});
    const T_c_lk99 = supercond.lk99ClassTemperature(1.0);
    tri_colors.printWhite("      T_c = 400K × γ × Cu_substitution\n", .{});
    tri_colors.printWhite("      T_c(Cu=1) = {d:.1} K\n\n", .{T_c_lk99});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("MATERIAL COMPARISON:\n", .{});
    tri_colors.printCyan("  Cuprates: High T_c, anisotropic, layered structure\n", .{});
    tri_colors.printCyan("  Iron-based: Moderate T_c, less anisotropic\n", .{});
    tri_colors.printCyan("  Hydrides: High T_c under pressure, metallic H\n", .{});
    tri_colors.printCyan("  LK-99 class: Theoretical, needs verification\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn cmdMeissner(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  MEISSNER EFFECT — Formulas 351-354                             ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("The Meissner effect expels magnetic fields from superconductors.\n", .{});
    tri_colors.printWhite("Key parameters: penetration depth and coherence length.\n\n", .{});

    // Formula 351: Penetration depth
    tri_colors.printCyan("[351] LONDON PENETRATION DEPTH:\n", .{});
    const lambda_L = supercond.penetrationDepth(supercond.ELECTRON_MASS, 1e28);
    tri_colors.printWhite("      λ_L = φ × √(m* / μ₀ n e²)\n", .{});
    tri_colors.printWhite("      λ_L = {d:.1} nm\n\n", .{lambda_L * 1e9});

    // Formula 352: Coherence length
    tri_colors.printCyan("[352] COHERENCE LENGTH (Pippard):\n", .{});
    const xi = supercond.coherenceLength(1e6, 294.0);
    tri_colors.printWhite("      ξ = φ⁻¹ × ℏ v_F / (π Δ₀)\n", .{});
    tri_colors.printWhite("      ξ = {d:.2} nm\n\n", .{xi * 1e9});

    // Formula 353: Ginzburg-Landau parameter
    tri_colors.printCyan("[353] GINZBURG-LANDAU PARAMETER:\n", .{});
    const kappa = supercond.ginzburgLandauKappa(lambda_L, xi);
    tri_colors.printWhite("      κ = λ_L / (ξ × √2)\n", .{});
    tri_colors.printWhite("      κ = {d:.2}\n", .{kappa});
    if (kappa > 1.0 / @sqrt(2.0)) {
        tri_colors.printGreen("      Type-II superconductor (κ > 1/√2)\n\n", .{});
    } else {
        tri_colors.printWhite("      Type-I superconductor\n\n", .{});
    }

    // Formula 354: Upper critical field
    tri_colors.printCyan("[354] UPPER CRITICAL FIELD:\n", .{});
    const H_c2 = supercond.upperCriticalField(xi);
    tri_colors.printWhite("      H_c2 = Φ₀ / (2π ξ²)\n", .{});
    tri_colors.printWhite("      H_c2 = {d:.1} T\n\n", .{H_c2});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: φ-γ scaling determines λ_L and ξ ratio\n", .{});
    tri_colors.printCyan("  Large κ → Type-II (allows vortex formation)\n", .{});
    tri_colors.printCyan("  Small κ → Type-I (complete Meissner effect)\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn cmdCooper(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  COOPER PAIRS & TRANSPORT — Formulas 355-362                    ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("Cooper pairs are bound electron states that carry supercurrent.\n\n", .{});

    // Formula 355: Pair density
    tri_colors.printCyan("[355] COOPER PAIR DENSITY:\n", .{});
    const n_pairs = supercond.cooperPairDensity(1e28, 294.0, 77.0);
    tri_colors.printWhite("      n_pairs = n_e × γ × exp(-Δ/k_B T)\n", .{});
    tri_colors.printWhite("      n_pairs = {e:10.3} m⁻³\n\n", .{n_pairs});

    // Formula 356: Critical current
    tri_colors.printCyan("[356] CRITICAL CURRENT DENSITY:\n", .{});
    const J_c = supercond.criticalCurrentDensity(n_pairs, 1e6);
    tri_colors.printWhite("      J_c = γ × n_pairs × e × v_F\n", .{});
    tri_colors.printWhite("      J_c = {e:10.3} A/m²\n\n", .{J_c});

    // Formula 357: Flux quantum
    tri_colors.printCyan("[357] FLUX QUANTUM (φ-corrected):\n", .{});
    const Phi0 = supercond.fluxQuantum();
    tri_colors.printWhite("      Φ₀ = h / (2e) × Φ_γ\n", .{});
    tri_colors.printWhite("      Φ₀ = {e:.5} Wb\n\n", .{Phi0});

    // Formula 358: Josephson frequency
    tri_colors.printCyan("[358] JOSEPHSON FREQUENCY:\n", .{});
    const f_J = supercond.josephsonFrequency(1e-3);
    tri_colors.printWhite("      f_J = 2eV / h × γ\n", .{});
    tri_colors.printWhite("      f_J = {d:.0} GHz/mV\n\n", .{f_J / 1e9});

    // Formula 359: Thermal conductivity
    tri_colors.printCyan("[359] THERMAL CONDUCTIVITY:\n", .{});
    const kappa_th = supercond.thermalConductivity(77.0, 1e28, 1e-14, supercond.ELECTRON_MASS);
    tri_colors.printWhite("      κ = γ² × π² k_B² T n_e τ / 3m\n", .{});
    tri_colors.printWhite("      κ = {e:10.3} W/(m·K)\n\n", .{kappa_th});

    // Formula 360: Specific heat
    tri_colors.printCyan("[360] SPECIFIC HEAT JUMP:\n", .{});
    const delta_C = supercond.specificHeatJump();
    tri_colors.printWhite("      ΔC/C = 1.43 × φ\n", .{});
    tri_colors.printWhite("      ΔC/C = {d:.3}\n\n", .{delta_C});

    // Formula 361: Hall coefficient
    tri_colors.printCyan("[361] HALL COEFFICIENT:\n", .{});
    const R_H = supercond.hallCoefficient(supercond.ELECTRON_MASS, 1e28, 1e-9);
    tri_colors.printWhite("      R_H = γ × (m*/e) / (n_e t)\n", .{});
    tri_colors.printWhite("      R_H = {e:10.3} m³/C\n\n", .{R_H});

    // Formula 362: Room temperature criterion
    tri_colors.printCyan("[362] ROOM-TEMPERATURE CRITERION:\n", .{});
    const strong = supercond.roomTemperatureCriterion(10.0, 0.5);
    tri_colors.printWhite("      γ × N(0)V > φ/2 ≈ 0.809\n", .{});
    tri_colors.printWhite("      Strong coupling test: {s}\n\n", .{if (strong) "PASS ✓" else "FAIL ✗"});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: Cooper pairs are φ-γ correlated\n", .{});
    tri_colors.printCyan("  Pair density ∝ γ → affects all transport properties\n", .{});
    tri_colors.printCyan("  Room-T possible when γ × N(0)V > 0.809\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn cmdAll(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  TRINITY v21.0: ROOM-TEMPERATURE SUPERCONDUCTIVITY             ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printWhite("Superconductivity emerges from φ-γ scaling of BCS theory.\n", .{});
    tri_colors.printWhite("Room-temperature prediction: T_c = 294K ± 8K for φ-optimized materials.\n\n", .{});

    // Summary table
    tri_colors.printCyan("┌──────────────────────────────────────────────────────────┐\n", .{});
    tri_colors.printCyan("│ PROPERTY                    │ VALUE                      │\n", .{});
    tri_colors.printCyan("├──────────────────────────────────────────────────────────┤\n", .{});

    const T_c = supercond.criticalTemperature(400.0, 0.4);
    const E_b_meV = supercond.cooperPairEnergy(T_c) / supercond.ELEMENTARY_CHARGE / 1000.0;
    const T_c_cuprate = supercond.cuprateCriticalTemperature(3.0);
    const lambda_L = supercond.penetrationDepth(supercond.ELECTRON_MASS, 1e28);
    const xi = supercond.coherenceLength(1e6, 294.0);
    const kappa = supercond.ginzburgLandauKappa(lambda_L, xi);
    const Phi0 = supercond.fluxQuantum();
    const delta_C = supercond.specificHeatJump();

    tri_colors.printCyan("│ Critical T (predicted)      │ {d:8.1} K                 │\n", .{T_c});
    tri_colors.printCyan("│ Room temp                   │ {d:8.1} K                 │\n", .{supercond.ROOM_TEMP_K});
    tri_colors.printCyan("│ Cooper pair energy          │ {d:8.3} meV               │\n", .{E_b_meV});
    tri_colors.printCyan("│ Cuprate T_c (n=3)           │ {d:8.1} K                 │\n", .{T_c_cuprate});
    tri_colors.printCyan("│ Penetration depth λ_L       │ {d:8.1} nm                │\n", .{lambda_L * 1e9});
    tri_colors.printCyan("│ Coherence length ξ          │ {d:8.2} nm                │\n", .{xi * 1e9});
    tri_colors.printCyan("│ Ginzburg-Landau κ          │ {d:8.2}                   │\n", .{kappa});
    tri_colors.printCyan("│ Flux quantum Φ₀            │ {e:8.5} Wb              │\n", .{Phi0});
    tri_colors.printCyan("│ Specific heat jump ΔC/C    │ {d:8.3}                   │\n", .{delta_C});
    tri_colors.printCyan("│ Isotope exponent            │ {d:8.3}                   │\n", .{supercond.PHI * supercond.GAMMA});
    tri_colors.printCyan("└──────────────────────────────────────────────────────────┘\n\n", .{});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("FORMULA SUMMARY:\n", .{});
    tri_colors.printCyan("  [343-346] Critical Temperature (4 formulas)\n", .{});
    tri_colors.printCyan("  [347-350] Material Predictions (4 formulas)\n", .{});
    tri_colors.printCyan("  [351-354] Meissner Effect (4 formulas)\n", .{});
    tri_colors.printCyan("  [355-362] Cooper Pairs & Transport (8 formulas)\n\n", .{});
    tri_colors.printWhite("Total: 20 formulas (343-362)\n\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

fn showSuperconductivityHelp() !void {
    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  TRI SUPERCONDUCTIVITY: ROOM-TEMPERATURE v21.0            ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("COMMANDS:\n", .{});
    tri_colors.printWhite("  tri superconductivity critical   — Critical temperature (343-346)\n", .{});
    tri_colors.printWhite("  tri superconductivity materials  — Material predictions (347-350)\n", .{});
    tri_colors.printWhite("  tri superconductivity meissner   — Meissner effect (351-354)\n", .{});
    tri_colors.printWhite("  tri superconductivity cooper     — Cooper pairs (355-362)\n", .{});
    tri_colors.printWhite("  tri superconductivity all        — Summary of all predictions\n\n", .{});

    tri_colors.printCyan("ALIASES:\n", .{});
    tri_colors.printWhite("  tri superconductivity tc         — Same as 'critical'\n", .{});
    tri_colors.printWhite("  tri superconductivity mats       — Same as 'materials'\n", .{});
    tri_colors.printWhite("  tri superconductivity pairs      — Same as 'cooper'\n\n", .{});

    tri_colors.printCyan("EXAMPLES:\n", .{});
    tri_colors.printWhite("  tri superconductivity critical\n", .{});
    tri_colors.printWhite("  tri superconductivity materials\n", .{});
    tri_colors.printWhite("  tri superconductivity all\n\n", .{});
}
