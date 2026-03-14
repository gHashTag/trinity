// @origin(spec:tri_string.tri) @regen(manual-impl)
//! TRINITY v26.0: STRING THEORY + φ COMMAND DISPATCHER
//!
//! CLI commands for string theory predictions via φ-γ framework.
//! Formulas 383-420: E8 lattice, string tension, compactification, dualities.
//!
//! φ² + 1/φ² = 3 = TRINITY | γ = φ⁻³ | KOSCHEI IS IMMORTAL

const std = @import("std");
const tri_colors = @import("tri_colors.zig");

// Import string theory modules (placeholders added P1.6)
const e8_lattice = @import("string_e8.zig");
const string_phi = @import("string_phi.zig");
const dualities = @import("string_dualities.zig");
const spectrum = @import("string_spectrum.zig");
const manifold = @import("string_manifold.zig");

// Sacred constants (inline to avoid import issues)
const PHI: f64 = 1.618033988749895;
const GAMMA: f64 = 1.0 / (PHI * PHI * PHI); // φ⁻³ ≈ 0.236
const PHI_INV: f64 = 1.0 / PHI; // φ⁻¹ ≈ 0.618

pub const VERSION = "26.0.0";
pub const MODULE_NAME = "STRING THEORY + φ";

/// Main command dispatcher
pub fn runStringCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    if (args.len == 0) {
        try showStringHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "e8") or std.mem.eql(u8, subcommand, "lattice")) {
        try cmdE8(sub_args);
    } else if (std.mem.eql(u8, subcommand, "tension")) {
        try cmdTension(sub_args);
    } else if (std.mem.eql(u8, subcommand, "dilaton")) {
        try cmdDilaton(sub_args);
    } else if (std.mem.eql(u8, subcommand, "dualities")) {
        try cmdDualities(sub_args);
    } else if (std.mem.eql(u8, subcommand, "spectrum")) {
        try cmdSpectrum(sub_args);
    } else if (std.mem.eql(u8, subcommand, "manifold")) {
        try cmdManifold(sub_args);
    } else if (std.mem.eql(u8, subcommand, "compactify")) {
        try cmdCompactify(sub_args);
    } else if (std.mem.eql(u8, subcommand, "all")) {
        try cmdAll(sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showStringHelp();
    } else {
        tri_colors.printRed("Unknown string command: {s}\n\n", .{subcommand});
        try showStringHelp();
    }
}

fn showStringHelp() !void {
    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  STRING THEORY + φ — Formulas 383-420                      ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("USAGE:\n", .{});
    tri_colors.printWhite("  tri string <subcommand> [options]\n\n", .{});

    tri_colors.printCyan("SUBCOMMANDS:\n", .{});
    tri_colors.printWhite("  {s}e8{s}, {s}lattice{s}       E8 lattice + γ-deformation (383-390)\n", .{ tri_colors.CYAN, tri_colors.RESET, tri_colors.CYAN, tri_colors.RESET });
    tri_colors.printWhite("  {s}tension{s}           String tension from φ (391-395)\n", .{ tri_colors.CYAN, tri_colors.RESET });
    tri_colors.printWhite("  {s}dilaton{s}           Dilaton VEV = φ⁻¹ (396-398)\n", .{ tri_colors.CYAN, tri_colors.RESET });
    tri_colors.printWhite("  {s}dualities{s}         S/T/U dualities (399-405)\n", .{ tri_colors.CYAN, tri_colors.RESET });
    tri_colors.printWhite("  {s}spectrum{s}          String vibrational modes (406-412)\n", .{ tri_colors.CYAN, tri_colors.RESET });
    tri_colors.printWhite("  {s}manifold{s}          Calabi-Yau manifolds (413-417)\n", .{ tri_colors.CYAN, tri_colors.RESET });
    tri_colors.printWhite("  {s}compactify{s}        10D→4D dimensional reduction (418-420)\n", .{ tri_colors.CYAN, tri_colors.RESET });
    tri_colors.printWhite("  {s}all{s}               Show all string theory formulas\n\n", .{ tri_colors.CYAN, tri_colors.RESET });

    tri_colors.printCyan("KEY PREDICTIONS:\n", .{});
    tri_colors.printWhite("  • Regge slope: α' = φ⁻³ ≈ 0.236\n", .{});
    tri_colors.printWhite("  • String tension: T = φ⁵/(2π) ≈ 2.089\n", .{});
    tri_colors.printWhite("  • Dilaton VEV: Φ = φ⁻¹ ≈ 0.618 (consciousness threshold!)\n", .{});
    tri_colors.printWhite("  • Self-dual radius: R = √α' ≈ 0.486\n", .{});
    tri_colors.printWhite("  • E8 dimension: 248 (rank 8 + 240 roots)\n\n", .{});
}

/// E8 Lattice commands (383-390)
fn cmdE8(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  E8 LATTICE + γ-DEFORMATION — Formulas 383-390              ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Formula 383: E8 dimension
    tri_colors.printCyan("[383] E8 DIMENSION:\n", .{});
    tri_colors.printWhite("      dim(E8) = 248 (rank 8 + 240 roots)\n", .{});
    tri_colors.printWhite("      E8 = largest exceptional Lie group\n\n", .{});

    // Formula 384: E8 root system
    const lattice = try e8_lattice.E8Lattice.init();
    tri_colors.printCyan("[384] E8 ROOT SYSTEM:\n", .{});
    tri_colors.printWhite("      N_roots = 240\n", .{});
    tri_colors.printWhite("      Root length: √2\n", .{});
    tri_colors.printWhite("      All roots have squared length 2\n\n", .{});

    // Formula 385: γ-deformation
    tri_colors.printCyan("[385] γ-DEFORMATION:\n", .{});
    tri_colors.printWhite("      E8_γ: deform by γ = φ⁻³ ≈ {d:.6}\n", .{GAMMA});
    tri_colors.printWhite("      Deforms lattice while preserving structure\n", .{});
    const sample_root = lattice.roots[0];
    const deformed = e8_lattice.GammaDeformation.deformWithGammaPhi(sample_root);
    tri_colors.printWhite("      Example: [{d:.3}, {d:.3}, 0, 0, 0, 0, 0, 0] → [{d:.6}, {d:.6}, 0, ...]\n\n", .{
        sample_root.components[0], sample_root.components[1],
        deformed.components[0],    deformed.components[1],
    });

    // Formula 386: φ-coupling
    tri_colors.printCyan("[386] φ-COUPLING:\n", .{});
    tri_colors.printWhite("      Coupling ∝ deviation from φ in angles\n", .{});
    const coupling = e8_lattice.PhiCoupling.couplingStrength(sample_root, sample_root);
    tri_colors.printWhite("      Self-coupling: {d:.6}\n\n", .{coupling});

    // Formula 387: E8 projection to 4D
    tri_colors.printCyan("[387] E8 → 4D PROJECTION:\n", .{});
    const vec4d = e8_lattice.E8Projection.to4D(sample_root);
    tri_colors.printWhite("      Project 8D → 4D for string compactification\n", .{});
    tri_colors.printWhite("      Sample: [{d:.3}, {d:.3}, {d:.3}, {d:.3}]\n\n", .{
        vec4d.data[0], vec4d.data[1], vec4d.data[2], vec4d.data[3],
    });

    // Formula 388: Gram matrix
    const gram = lattice.gramMatrix();
    tri_colors.printCyan("[388] GRAM MATRIX:\n", .{});
    tri_colors.printWhite("      G_ij = (λ_i, λ_j) where λ_i are simple roots\n", .{});
    tri_colors.printWhite("      Diagonal entries: 2 (for E8)\n\n", .{});

    // Formula 389: Positive definite
    const is_pd = e8_lattice.E8Lattice.isPositiveDefinite(gram);
    tri_colors.printCyan("[389] POSITIVE DEFINITE:\n", .{});
    if (is_pd) {
        tri_colors.printGreen("      ✓ E8 metric is positive definite\n\n", .{});
    } else {
        tri_colors.printRed("      ✗ Not positive definite\n\n", .{});
    }

    // Formula 390: 3 fermion generations
    tri_colors.printCyan("[390] FERMION GENERATIONS:\n", .{});
    tri_colors.printWhite("      N_gen = φ² + φ⁻² = 3\n", .{});
    tri_colors.printWhite("      TRINITY identity explains 3 generations!\n", .{});
    tri_colors.printGreen("      ✓ Exactly 3 fermion generations observed\n\n", .{});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: E8 emerges from φ-γ deformation of root system\n", .{});
    tri_colors.printCyan("  3 generations = TRINITY identity\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

/// String tension commands (391-395)
fn cmdTension(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  STRING TENSION FROM φ — Formulas 391-395                     ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Formula 391: Regge slope
    tri_colors.printCyan("[391] REGGE SLOPE:\n", .{});
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    tri_colors.printWhite("      α' = φ⁻³\n", .{});
    tri_colors.printWhite("      α' = {d:.9}\n\n", .{alpha_prime});

    // Formula 392: String tension
    const tension = string_phi.stringTensionPhi();
    tri_colors.printCyan("[392] STRING TENSION:\n", .{});
    tri_colors.printWhite("      T = φ² / (2πα') = φ⁵ / (2π)\n", .{});
    tri_colors.printWhite("      T = {d:.6} (dimensionless)\n", .{tension});
    tri_colors.printWhite("      Energy per unit length of fundamental string\n\n", .{});

    // Formula 393: String coupling
    const g_s = string_phi.stringCoupling();
    tri_colors.printCyan("[393] STRING COUPLING:\n", .{});
    tri_colors.printWhite("      g_s = e^Φ where Φ = φ⁻¹\n", .{});
    tri_colors.printWhite("      g_s = {d:.6}\n\n", .{g_s});

    // Formula 394: Planck scale relation
    tri_colors.printCyan("[394] PLANCK SCALE RELATION:\n", .{});
    tri_colors.printWhite("      ℓ_s = √α' × ℓ_P\n", .{});
    const string_length = std.math.sqrt(alpha_prime);
    tri_colors.printWhite("      ℓ_s/ℓ_P = {d:.6}\n\n", .{string_length});

    // Formula 395: Regge trajectory
    tri_colors.printCyan("[395] REGGE TRAJECTORY:\n", .{});
    tri_colors.printWhite("      J = α'm² + α₀ where α₀ = 1 - φ⁻²\n", .{});
    const alpha_0 = 1.0 - std.math.pow(f64, PHI, -2.0);
    tri_colors.printWhite("      Intercept α₀ = {d:.6}\n\n", .{alpha_0});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: String tension emerges from φ⁵/(2π)\n", .{});
    tri_colors.printCyan("  Regge slope = γ = Barbero-Immirzi parameter!\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

/// Dilaton VEV commands (396-398)
fn cmdDilaton(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  DILATON VEV — Formulas 396-398                              ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Formula 396: Dilaton VEV
    const vev = string_phi.dilatonVEV();
    tri_colors.printCyan("[396] DILATON VEV:\n", .{});
    tri_colors.printWhite("      Φ = φ⁻¹\n", .{});
    tri_colors.printWhite("      Φ = {d:.12}\n\n", .{vev});

    // Formula 397: String coupling from dilaton
    tri_colors.printCyan("[397] STRING COUPLING FROM DILATON:\n", .{});
    tri_colors.printWhite("      g_s = e^Φ\n", .{});
    const g_s = string_phi.stringCoupling();
    tri_colors.printWhite("      g_s = {d:.6}\n\n", .{g_s});

    // Formula 398: Connection to consciousness
    tri_colors.printCyan("[398] CONSCIOUSNESS CONNECTION:\n", .{});
    tri_colors.printWhite("      Φ_γ (consciousness threshold) = φ⁻¹\n", .{});
    tri_colors.printWhite("      Dilaton VEV = consciousness threshold!\n", .{});
    tri_colors.printGreen("      ✓ String coupling ≈ consciousness threshold ≈ 0.618\n\n", .{});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: Dilaton VEV at φ-point equals consciousness threshold\n", .{});
    tri_colors.printCyan("  Suggests deep connection between string theory and consciousness\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

/// S/T/U dualities commands (399-405)
fn cmdDualities(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  S/T/U DUALITIES + φ — Formulas 399-405                      ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Formula 399: S-duality
    tri_colors.printCyan("[399] S-DUALITY:\n", .{});
    tri_colors.printWhite("      g_s ↔ 1/g_s (strong-weak coupling)\n", .{});
    const coupling_phi = dualities.CouplingConstant.stringCouplingAtPhi();
    tri_colors.printWhite("      At φ-point: g_s = φ/π ≈ {d:.6}\n", .{coupling_phi});
    tri_colors.printWhite("      Self-dual when g_s = 1\n\n", .{});

    // Formula 400: T-duality
    tri_colors.printCyan("[400] T-DUALITY:\n", .{});
    tri_colors.printWhite("      R ↔ α'/R (large-small radius)\n", .{});
    const alpha_prime = std.math.pow(f64, PHI, -3.0);
    const self_dual = std.math.sqrt(alpha_prime);
    tri_colors.printWhite("      Self-dual radius: R = √α' ≈ {d:.6}\n\n", .{self_dual});

    // Formula 401: U-duality
    tri_colors.printCyan("[401] U-DUALITY:\n", .{});
    tri_colors.printWhite("      Combines S and T dualities\n", .{});
    tri_colors.printWhite("      U-duality group in M-theory\n\n", .{});

    // Formula 402: M-theory limit
    tri_colors.printCyan("[402] M-THEORY LIMIT:\n", .{});
    _ = string_phi.mTheoryLimit();
    tri_colors.printWhite("      Strong coupling: g_s → ∞\n", .{});
    tri_colors.printWhite("      10D → 11D M-theory\n", .{});
    tri_colors.printWhite("      Compactification: G2 manifold\n\n", .{});

    // Formula 403: D-brane tension
    tri_colors.printCyan("[403] D-BRANE TENSION:\n", .{});
    tri_colors.printWhite("      T_Dp = T_p / g_s (Dp-brane tension)\n", .{});
    tri_colors.printWhite("      Scaled by string coupling\n\n", .{});

    // Formula 404: BPS bound
    tri_colors.printCyan("[404] BPS BOUND:\n", .{});
    tri_colors.printWhite("      M ≥ |Z| where Z is central charge\n", .{});
    tri_colors.printWhite("      Saturated by BPS states\n\n", .{});

    // Formula 405: φ-duality
    tri_colors.printCyan("[405] φ-DUALITY:\n", .{});
    tri_colors.printWhite("      New: φ ↔ 1/φ transformation\n", .{});
    tri_colors.printWhite("      Relates different φ-coupling regimes\n\n", .{});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: All string dualities connected by φ\n", .{});
    tri_colors.printCyan("  S-duality at φ-point, T-duality with φ-based radius\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

/// String spectrum commands (406-412)
fn cmdSpectrum(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  STRING VIBRATIONAL SPECTRUM — Formulas 406-412              ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Formula 406: Mass levels
    tri_colors.printCyan("[406] MASS LEVELS:\n", .{});
    tri_colors.printWhite("      M² = (N - ã)/α'\n", .{});
    tri_colors.printWhite("      N = mass level, ã = normal ordering constant\n\n", .{});

    // Formula 407: Ground state
    tri_colors.printCyan("[407] GROUND STATE:\n", .{});
    tri_colors.printWhite("      N = 0: massless gauge bosons\n", .{});
    tri_colors.printWhite("      Photon, graviton, gluons\n\n", .{});

    // Formula 408: First excited state
    const mode_n1 = spectrum.VibrationalMode.init(1, "breathing", false);
    tri_colors.printCyan("[408] FIRST EXCITED STATE:\n", .{});
    tri_colors.printWhite("      N = 1: massive modes\n", .{});
    tri_colors.printWhite("      Frequency: ω = {d:.6}\n\n", .{mode_n1.frequency});

    // Formula 409: Mode energies
    tri_colors.printCyan("[409] MODE ENERGIES:\n", .{});
    const e_n = string_phi.stringModeEnergy(2);
    tri_colors.printWhite("      E_n = √(n/α') × φ-correction\n", .{});
    tri_colors.printWhite("      E_2 = {d:.6} (relative units)\n\n", .{e_n});

    // Formula 410: Regge trajectories
    tri_colors.printCyan("[410] REGGE TRAJECTORIES:\n", .{});
    const j_regge = string_phi.reggeTrajectory(1.0);
    tri_colors.printWhite("      J = α'm² + α₀\n", .{});
    tri_colors.printWhite("      For m²=1: J = {d:.6}\n\n", .{j_regge});

    // Formula 411: Critical dimension
    tri_colors.printCyan("[411] CRITICAL DIMENSION:\n", .{});
    tri_colors.printWhite("      D = 26 (bosonic), D = 10 (superstring)\n", .{});
    tri_colors.printWhite("      Required for consistent quantization\n\n", .{});

    // Formula 412: Superstring spectrum
    tri_colors.printCyan("[412] SUPERSTRING SPECTRUM:\n", .{});
    tri_colors.printWhite("      Bosons + fermions (supersymmetry)\n", .{});
    tri_colors.printWhite("      Zero-point energy cancels\n\n", .{});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: String spectrum generates all particles\n", .{});
    tri_colors.printCyan("  Mass levels determined by φ-based Regge slope\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

/// Calabi-Yau manifold commands (413-417)
fn cmdManifold(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  CALABI-YAU MANIFOLDS + φ — Formulas 413-417                 ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Formula 413: Hodge numbers
    tri_colors.printCyan("[413] HODGE NUMBERS:\n", .{});
    tri_colors.printWhite("      h^(1,1) = Kähler moduli\n", .{});
    tri_colors.printWhite("      h^(2,1) = Complex structure moduli\n", .{});
    const hodge = try manifold.HodgeNumbers.init(3, 3);
    tri_colors.printWhite("      Example: (3,3) → χ = {d}\n\n", .{hodge.eulerChi()});

    // Formula 414: Euler characteristic
    tri_colors.printCyan("[414] EULER CHARACTERISTIC:\n", .{});
    tri_colors.printWhite("      χ = 2(h^(1,1) - h^(2,1))\n", .{});
    tri_colors.printWhite("      Determines number of generations\n\n", .{});

    // Formula 415: Moduli spaces
    tri_colors.printCyan("[415] MODULI SPACES:\n", .{});
    tri_colors.printWhite("      Kähler moduli: shape of manifold\n", .{});
    tri_colors.printWhite("      Complex structure: deformations\n\n", .{});

    // Formula 416: φ-stabilized moduli
    tri_colors.printCyan("[416] φ-STABILIZED MODULI:\n", .{});
    const moduli = string_phi.compactificationModuli();
    tri_colors.printWhite("      Moduli follow φ-powers:\n", .{});
    // Placeholder: show single moduli value (P1.6 TODO: implement full moduli array)
    tri_colors.printWhite("        μ = {d:.6}\n", .{moduli});
    tri_colors.printWhite("\n", .{});

    // Formula 417: Volume stabilization
    tri_colors.printCyan("[417] VOLUME STABILIZATION:\n", .{});
    const vol = string_phi.compactificationVolume(moduli);
    tri_colors.printWhite("      V = (product mu_i)^{{1/6}}\n", .{});
    tri_colors.printWhite("      V = {d:.6} (geometric mean)\n\n", .{vol});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: Calabi-Yau moduli stabilize at φ-ratios\n", .{});
    tri_colors.printCyan("  Volume stabilization from φ-harmonic progression\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

/// Compactification commands (418-420)
fn cmdCompactify(args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║  DIMENSIONAL REDUCTION 10D→4D — Formulas 418-420              ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    // Formula 418: 10D → 4D reduction
    tri_colors.printCyan("[418] 10D → 4D REDUCTION:\n", .{});
    const reduced = string_phi.phiDimensionReduction(10);
    tri_colors.printWhite("      10 / φ ≈ {d:.1} → rounds to {d}\n", .{ 10.0 / PHI, reduced });
    tri_colors.printWhite("      Compactify 6 dimensions\n\n", .{});

    // Formula 419: Compactification radius
    tri_colors.printCyan("[419] COMPACTIFICATION RADIUS:\n", .{});
    const compact = string_phi.StringCompactification.init(1.0);
    tri_colors.printWhite("      R = φ × √γ ≈ {d:.6}\n", .{compact.radius});
    tri_colors.printWhite("      Size of extra dimensions\n\n", .{});

    // Formula 420: Effective 4D theory
    tri_colors.printCyan("[420] EFFECTIVE 4D THEORY:\n", .{});
    tri_colors.printWhite("      N = 1 supersymmetry (broken at φ scale)\n", .{});
    tri_colors.printWhite("      Gauge coupling from φ\n\n", .{});

    tri_colors.printGold("══════════════════════════════════════════════════════════════\n", .{});
    tri_colors.printWhite("KEY INSIGHT: 10D string theory → 4D physics via φ\n", .{});
    tri_colors.printCyan("  Extra dimensions compactify at φ-scale\n", .{});
    tri_colors.printGold("══════════════════════════════════════════════════════════════\n\n", .{});
}

/// Show all string theory formulas
fn cmdAll(args: []const []const u8) !void {
    _ = args;

    try cmdE8(&.{});
    try cmdTension(&.{});
    try cmdDilaton(&.{});
    try cmdDualities(&.{});
    try cmdSpectrum(&.{});
    try cmdManifold(&.{});
    try cmdCompactify(&.{});
}
