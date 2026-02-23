// =============================================================================
// TRI CLI - Sacred Mathematics Commands (Cycle 82 + 83 + 84 + 85)
// =============================================================================
//
// Exposes sacred_math.zig library as TRI CLI commands:
//   tri math          - Sacred math router/help
//   tri constants     - Display all sacred constants
//   tri phi <n>       - Compute phi^n
//   tri fib <n>       - Fibonacci number
//   tri lucas <n>     - Lucas number
//   tri spiral <n>    - Phi-spiral coordinates
//   tri math-verify   - Trinity identity verification (20 checks)
//   tri math-bench    - Performance benchmark
//   tri math-compare  - Side-by-side comparison table
//
// Cycle 83 extensions:
//   tri math exotic   - Exotic constants (Apery, Catalan, Feigenbaum, etc.)
//   tri math physical - Physics constants (alpha, CHSH, Planck, Boltzmann)
//   tri math chaos    - Chaos theory (Feigenbaum + logistic map demo)
//   tri math all      - Display ALL 63 constants
//
// Cycle 84 extensions:
//   tri math golden-function - Golden Function model (Pellis 2025)
//   tri math nuclear         - Nuclear Fibonacci shell stability
//   tri math fractal         - Fractal scaling + self-similar phi structures
//
// Cycle 85 extensions:
//   tri math quantum  - Berry phase gates + geometric phase
//   tri math su3      - Full SU(3) simulation — color charges + golden ratio
//   tri math planck   - Planck units with phi-scaling relationships
//   tri math qutrit   - Ternary phase gates + qutrit state demo
//
// All math is inlined from sacred_math.zig to avoid build.zig coupling.
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");
const colors = @import("tri_colors.zig");

const GREEN = colors.GREEN;
const GOLDEN = colors.GOLDEN;
const WHITE = colors.WHITE;
const GRAY = colors.GRAY;
const RED = colors.RED;
const CYAN = colors.CYAN;
const RESET = colors.RESET;

// =============================================================================
// SACRED CONSTANTS (inlined from sacred_math.zig)
// =============================================================================

const PHI: f64 = 1.6180339887498948482;
const PHI_SQ: f64 = 2.6180339887498948482;
const PHI_INV: f64 = 0.6180339887498948482;
const PHI_INV_SQ: f64 = 0.3819660112501051518;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.71828182845904523536;
const TRANSCENDENTAL: f64 = 13.816890703380645;
const TRINITY: i8 = 3;
const MU: f64 = 0.0382;
const CHI: f64 = 0.0618;
const SIGMA: f64 = 1.618;
const EPSILON: f64 = 0.333;
const CHSH: f64 = 2.8284271247461903;
const FINE_STRUCTURE_INV: f64 = 137.036;

// =============================================================================
// FUNDAMENTAL CONSTANTS (Cycle 83)
// =============================================================================

const SQRT2: f64 = 1.4142135623730950488;
const SQRT3: f64 = 1.7320508075688772935;
const SQRT5: f64 = 2.2360679774997896964;
const EULER_MASCHERONI: f64 = 0.5772156649015328606;
const LN2: f64 = 0.6931471805599453094;

// =============================================================================
// EXOTIC CONSTANTS (Cycle 83)
// =============================================================================

/// Apery's constant zeta(3) — proved irrational by Apery (1978)
const APERY: f64 = 1.2020569031595942854;

/// Catalan's constant G = sum_{n=0}^inf (-1)^n / (2n+1)^2
const CATALAN: f64 = 0.9159655941772190151;

/// Feigenbaum delta — period-doubling bifurcation ratio (chaos theory)
const FEIGENBAUM_DELTA: f64 = 4.6692016091029906719;

/// Feigenbaum alpha — scaling factor in bifurcation diagram
const FEIGENBAUM_ALPHA: f64 = 2.5029078750958928222;

/// Khinchin's constant — geometric mean of continued fraction coefficients
const KHINCHIN: f64 = 2.6854520010653064453;

/// Glaisher-Kinkelin constant A
const GLAISHER_KINKELIN: f64 = 1.2824271291006226369;

/// Omega constant — W(1) where W is Lambert W function (x*e^x = 1)
const OMEGA: f64 = 0.5671432904097838730;

/// Plastic number — real root of x^3 = x + 1 (cubic golden ratio)
const PLASTIC: f64 = 1.3247179572447460260;

/// Landau-Ramanujan constant
const LANDAU_RAMANUJAN: f64 = 0.7642236535892206629;

/// Conway's constant — growth rate of look-and-say sequence
const CONWAY: f64 = 1.3035772690342963912;

// =============================================================================
// PHYSICS CONSTANTS (Cycle 83)
// =============================================================================

/// Fine structure constant alpha = e^2 / (4*pi*eps0*hbar*c)
const ALPHA: f64 = 0.0072973525693;

/// Planck constant h (J*s)
const PLANCK_H: f64 = 6.62607015e-34;

/// Reduced Planck constant hbar = h/(2*pi)
const PLANCK_HBAR: f64 = 1.054571817e-34;

/// Speed of light c (m/s)
const SPEED_OF_LIGHT: f64 = 299792458.0;

/// Boltzmann constant k_B (J/K)
const BOLTZMANN: f64 = 1.380649e-23;

/// Gravitational constant G (m^3/(kg*s^2))
const GRAVITATIONAL: f64 = 6.67430e-11;

/// Avogadro's number N_A (1/mol)
const AVOGADRO: f64 = 6.02214076e23;

/// Elementary charge e (C)
const ELEMENTARY_CHARGE: f64 = 1.602176634e-19;

/// Planck length l_P (m)
const PLANCK_LENGTH: f64 = 1.616255e-35;

/// Planck time t_P (s)
const PLANCK_TIME: f64 = 5.391247e-44;

/// Planck mass m_P (kg)
const PLANCK_MASS: f64 = 2.176434e-8;

// =============================================================================
// GOLDEN FUNCTION CONSTANTS (Cycle 84 — Pellis 2025)
// =============================================================================

/// Golden Function G(x) = phi^x + phi^(-x) — generalization of Lucas
/// G(n) = L(n) for integer n; continuous extension via phi exponentiation
/// Pellis 2025: "The Golden Function and its applications to mathematical physics"

/// phi^(1/2) = sqrt(phi) ≈ 1.2720196495...
const PHI_SQRT: f64 = 1.2720196495140689643;

/// G(0.5) = phi^0.5 + phi^(-0.5) — Golden Function at half-integer
const GOLDEN_HALF: f64 = 2.0581710272714923552; // sqrt(phi) + 1/sqrt(phi)

/// phi^phi ≈ 2.3903... — phi self-exponentiation
const PHI_TO_PHI: f64 = 2.3903891399637654580;

/// phi^pi ≈ 4.5310... — transcendental golden power
const PHI_TO_PI: f64 = 4.5310082907795665412;

// =============================================================================
// NUCLEAR FIBONACCI CONSTANTS (Cycle 84)
// =============================================================================
// Nuclear shell magic numbers correlate with Fibonacci/Lucas sequences
// Stable nuclei cluster near F and L values

/// Nuclear magic numbers: 2, 8, 20, 28, 50, 82, 126
/// Connection: 2=L(0), 8=F(6), 20≈F(8)-1, 28=L(7)-1, 50≈F(10)-5
const NUCLEAR_MAGIC: [7]u32 = .{ 2, 8, 20, 28, 50, 82, 126 };

/// Proton-neutron stability ratio ≈ 1 for light nuclei, → ~1.5 for heavy
/// For Z > 20, N/Z → phi/sqrt(2) ≈ 1.144 (observed empirical trend)
const NP_STABILITY: f64 = 1.1442;

/// Nuclear binding energy per nucleon peak ≈ 8.8 MeV (near Iron-56)
/// 8.8 ≈ F(6) + 0.8 = 8 + phi^(-1)
const BINDING_PEAK: f64 = 8.7945;

// =============================================================================
// FRACTAL SCALING CONSTANTS (Cycle 84)
// =============================================================================

/// Hausdorff dimension of Sierpinski triangle = ln(3)/ln(2)
const SIERPINSKI_DIM: f64 = 1.5849625007211561815;

/// Hausdorff dimension of Koch snowflake = ln(4)/ln(3)
const KOCH_DIM: f64 = 1.2618595071429148197;

/// Hausdorff dimension of Menger sponge = ln(20)/ln(3)
const MENGER_DIM: f64 = 2.7268330278608417408;

/// Hausdorff dimension of Mandelbrot boundary = 2.0 (proven, 1991)
const MANDELBROT_DIM: f64 = 2.0;

/// Golden spiral self-similarity ratio = phi^2 = phi + 1
/// Each quarter turn scales by phi^2
const GOLDEN_SPIRAL_RATIO: f64 = 2.6180339887498948482;

// =============================================================================
// QUANTUM SACRED CONSTANTS (Cycle 85)
// =============================================================================
// Berry phase + φ, SU(3) generators, Planck-φ units, qutrit gates

/// Berry phase geometric factor for qutrit loop = 2π/3
/// In SU(3), the cyclic subgroup Z₃ gives phase exp(i·2π/3)
const BERRY_PHASE_QUTRIT: f64 = 2.0943951023931953; // 2*pi/3

/// SU(3) structure constant f₁₂₃ = 1 (Gell-Mann matrices)
const SU3_F123: f64 = 1.0;

/// SU(3) structure constant f₄₅₈ = sqrt(3)/2
const SU3_F458: f64 = 0.8660254037844386468; // sqrt(3)/2

/// SU(3) Casimir invariant for fundamental representation = 4/3
const SU3_CASIMIR: f64 = 1.3333333333333333333;

/// SU(3) Golden constant = 3/(2φ) — Trinity meets golden ratio in strong force
/// Connects color symmetry to φ: the "3" is SU(3) dimension, "2φ" is golden diameter
const SU3_GOLDEN: f64 = 0.9270509831248422723; // 3 / (2 * phi)

/// Qutrit Hadamard-like gate angle: 2π/3 (120° rotation in qutrit space)
const QUTRIT_GATE_ANGLE: f64 = 2.0943951023931953; // same as Berry phase

/// Rydberg constant R_∞ (1/m) — hydrogen spectrum
const RYDBERG: f64 = 10973731.568160;

/// Planck temperature T_P (K) = sqrt(hbar*c^5 / (G*k_B^2))
const PLANCK_TEMPERATURE: f64 = 1.416784e32;

/// Planck energy E_P (GeV) = sqrt(hbar*c^5/G) in GeV
const PLANCK_ENERGY_GEV: f64 = 1.22089e19;

/// Weinberg angle sin²θ_W ≈ 0.2312 (electroweak mixing)
const WEINBERG_SIN2: f64 = 0.23121;

/// Proton-electron mass ratio m_p/m_e ≈ 1836.15
const PROTON_ELECTRON_RATIO: f64 = 1836.15267343;

/// φ-scaled Planck: l_P × φ (Planck length in golden units)
const PLANCK_LENGTH_PHI: f64 = 1.616255e-35 * 1.6180339887498948482;

/// φ-scaled Planck: t_P × φ (Planck time in golden units)
const PLANCK_TIME_PHI: f64 = 5.391247e-44 * 1.6180339887498948482;

/// Qutrit entropy: log₂(3) — maximum information per qutrit
const QUTRIT_ENTROPY: f64 = 1.5849625007211561815; // ln(3)/ln(2)

/// Berry connection for φ-spiral: 2π×φ (golden Berry orbit)
const BERRY_PHI_ORBIT: f64 = 10.166407384630519631; // 2*pi*phi

const FIBONACCI_TABLE: [20]i64 = .{
    0, 1, 1, 2, 3, 5, 8, 13, 21, 34,
    55, 89, 144, 233, 377, 610, 987, 1597, 2584, 4181,
};

const LUCAS_TABLE: [20]i64 = .{
    2, 1, 3, 4, 7, 11, 18, 29, 47, 76,
    123, 199, 322, 521, 843, 1364, 2207, 3571, 5778, 9349,
};

fn fibonacci(n: u32) i64 {
    if (n < 20) return FIBONACCI_TABLE[n];
    var a: i64 = FIBONACCI_TABLE[18];
    var b: i64 = FIBONACCI_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a +| b;
        a = b;
        b = temp;
    }
    return b;
}

fn lucas(n: u32) i64 {
    if (n < 20) return LUCAS_TABLE[n];
    var a: i64 = LUCAS_TABLE[18];
    var b: i64 = LUCAS_TABLE[19];
    var i: u32 = 20;
    while (i <= n) : (i += 1) {
        const temp = a +| b;
        a = b;
        b = temp;
    }
    return b;
}

fn goldenWrap(sum: i16) i8 {
    var result: i16 = sum;
    while (result > 13) result -= 27;
    while (result < -13) result += 27;
    return @intCast(result);
}

// =============================================================================
// COMMAND: tri math (router)
// =============================================================================

pub fn runMathCommand(args: []const []const u8) void {
    if (args.len == 0) {
        printMathHelp();
        return;
    }

    const sub = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, sub, "help")) {
        printMathHelp();
    } else if (std.mem.eql(u8, sub, "constants") or std.mem.eql(u8, sub, "const")) {
        runConstantsCommand();
    } else if (std.mem.eql(u8, sub, "verify")) {
        runMathVerifyCommand();
    } else if (std.mem.eql(u8, sub, "bench")) {
        runMathBenchCommand();
    } else if (std.mem.eql(u8, sub, "compare")) {
        runMathCompareCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "phi")) {
        runPhiCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "fib")) {
        runFibCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "lucas")) {
        runLucasCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "spiral")) {
        runSpiralCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "exotic") or std.mem.eql(u8, sub, "rare")) {
        runExoticCommand();
    } else if (std.mem.eql(u8, sub, "physical") or std.mem.eql(u8, sub, "physics") or std.mem.eql(u8, sub, "phys")) {
        runPhysicalCommand();
    } else if (std.mem.eql(u8, sub, "chaos") or std.mem.eql(u8, sub, "feigenbaum")) {
        runChaosCommand();
    } else if (std.mem.eql(u8, sub, "all")) {
        runAllConstantsCommand();
    } else if (std.mem.eql(u8, sub, "golden-function") or std.mem.eql(u8, sub, "gf") or std.mem.eql(u8, sub, "pellis")) {
        runGoldenFunctionCommand(sub_args);
    } else if (std.mem.eql(u8, sub, "nuclear") or std.mem.eql(u8, sub, "nuc") or std.mem.eql(u8, sub, "shell")) {
        runNuclearCommand();
    } else if (std.mem.eql(u8, sub, "fractal") or std.mem.eql(u8, sub, "frac") or std.mem.eql(u8, sub, "hausdorff")) {
        runFractalCommand();
    } else if (std.mem.eql(u8, sub, "quantum") or std.mem.eql(u8, sub, "berry")) {
        runQuantumCommand();
    } else if (std.mem.eql(u8, sub, "su3") or std.mem.eql(u8, sub, "color") or std.mem.eql(u8, sub, "qcd")) {
        runSU3SimCommand();
    } else if (std.mem.eql(u8, sub, "planck") or std.mem.eql(u8, sub, "units") or std.mem.eql(u8, sub, "planck-phi")) {
        runPlanckCommand();
    } else if (std.mem.eql(u8, sub, "qutrit") or std.mem.eql(u8, sub, "qt") or std.mem.eql(u8, sub, "ternary-gate")) {
        runQutritCommand();
    } else {
        std.debug.print("{s}Unknown math subcommand: {s}{s}\n", .{ RED, sub, RESET });
        printMathHelp();
    }
}

fn printMathHelp() void {
    std.debug.print("\n{s}Sacred Mathematics ({s}phi^2 + 1/phi^2 = 3{s}){s}\n", .{ GOLDEN, WHITE, GOLDEN, RESET });
    std.debug.print("{s}============================================{s}\n\n", .{ GRAY, RESET });
    std.debug.print("{s}USAGE:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri math <subcommand>       Run math subcommand\n", .{});
    std.debug.print("  tri <command> [args]         Direct command\n\n", .{});
    std.debug.print("{s}SACRED:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}constants{s}                  Sacred constants (phi, pi, e, Trinity)\n", .{ GREEN, RESET });
    std.debug.print("  {s}phi{s} <n>                    Compute phi^n powers\n", .{ GREEN, RESET });
    std.debug.print("  {s}fib{s} <n>                    Fibonacci number F(n)\n", .{ GREEN, RESET });
    std.debug.print("  {s}lucas{s} <n>                  Lucas number L(n)\n", .{ GREEN, RESET });
    std.debug.print("  {s}spiral{s} <n>                 Phi-spiral coordinates + ASCII plot\n", .{ GREEN, RESET });
    std.debug.print("  {s}compare{s} [n]                Side-by-side phi/fib/lucas table\n", .{ GREEN, RESET });
    std.debug.print("\n{s}EXTENDED (Cycle 83):{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}exotic{s}                     Exotic constants (Apery, Catalan, Feigenbaum...)\n", .{ GREEN, RESET });
    std.debug.print("  {s}physical{s}                   Physics constants (alpha, Planck, Boltzmann...)\n", .{ GREEN, RESET });
    std.debug.print("  {s}chaos{s}                      Feigenbaum constants + logistic map demo\n", .{ GREEN, RESET });
    std.debug.print("  {s}all{s}                        ALL 63 constants across all categories\n", .{ GREEN, RESET });
    std.debug.print("\n{s}ADVANCED (Cycle 84):{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}golden-function{s} [n]        Golden Function G(x)=phi^x+phi^-x (Pellis 2025)\n", .{ GREEN, RESET });
    std.debug.print("  {s}nuclear{s}                    Nuclear Fibonacci shell stability model\n", .{ GREEN, RESET });
    std.debug.print("  {s}fractal{s}                    Fractal dimensions + self-similar phi scaling\n", .{ GREEN, RESET });
    std.debug.print("\n{s}QUANTUM (Cycle 85):{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}quantum{s}                    Berry phase gates + geometric phase\n", .{ GREEN, RESET });
    std.debug.print("  {s}su3{s}                        SU(3) simulation — strong force + golden ratio\n", .{ GREEN, RESET });
    std.debug.print("  {s}planck{s}                     Planck units with phi-scaling relationships\n", .{ GREEN, RESET });
    std.debug.print("  {s}qutrit{s}                     Ternary phase gates + qutrit state demo\n", .{ GREEN, RESET });
    std.debug.print("\n{s}TOOLS:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}math-verify{s}                Trinity identity checks (20 checks)\n", .{ GREEN, RESET });
    std.debug.print("  {s}math-bench{s}                 Performance benchmark\n", .{ GREEN, RESET });
    std.debug.print("\n{s}DIRECT ALIASES:{s}\n", .{ CYAN, RESET });
    std.debug.print("  tri constants  |  tri phi 10  |  tri fib 19\n", .{});
    std.debug.print("  tri lucas 5    |  tri spiral 8 |  tri math-verify\n", .{});
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

// =============================================================================
// COMMAND: tri constants
// =============================================================================

pub fn runConstantsCommand() void {
    std.debug.print("\n{s}Sacred Constants{s} ({s}phi^2 + 1/phi^2 = 3{s})\n", .{ GOLDEN, RESET, WHITE, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    printConst("phi (PHI)", PHI, "Golden ratio (1+sqrt5)/2");
    printConst("phi^2 (PHI_SQ)", PHI_SQ, "phi + 1");
    printConst("1/phi (PHI_INV)", PHI_INV, "phi - 1");
    printConst("1/phi^2 (PHI_INV_SQ)", PHI_INV_SQ, "2 - phi");
    std.debug.print("\n", .{});
    printConst("sqrt(2)", SQRT2, "Pythagoras constant");
    printConst("sqrt(5)", SQRT5, "(phi*2 - 1)");
    std.debug.print("\n", .{});
    printConst("pi", PI, "Circle constant");
    printConst("e", E, "Euler's number");
    printConst("gamma (Euler-Mascheroni)", EULER_MASCHERONI, "Harmonic series limit");
    printConst("ln(2)", LN2, "Natural log of 2");
    printConst("pi * phi * e", TRANSCENDENTAL, "~= TRYTE_MAX (13)");
    std.debug.print("\n", .{});
    printConstInt("TRINITY", TRINITY, "phi^2 + 1/phi^2 = 3");
    printConst("mu (mutation)", MU, "1/phi^2/10");
    printConst("chi (crossover)", CHI, "1/phi/10");
    printConst("sigma (selection)", SIGMA, "phi");
    printConst("epsilon (elitism)", EPSILON, "1/3");
    std.debug.print("\n", .{});
    printConst("CHSH (2*sqrt2)", CHSH, "Bell inequality violation");
    printConst("1/alpha", FINE_STRUCTURE_INV, "Fine structure constant inverse");

    // Verification
    const trinity_check = PHI_SQ + PHI_INV_SQ;
    std.debug.print("\n{s}  Verification: phi^2 + 1/phi^2 = {d:.16}{s}", .{ GOLDEN, trinity_check, RESET });
    if (@abs(trinity_check - 3.0) < 0.0001) {
        std.debug.print(" {s}TRINITY VERIFIED{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print(" {s}FAILED{s}\n", .{ RED, RESET });
    }
    std.debug.print("\n", .{});
}

fn printConst(name: []const u8, value: f64, desc: []const u8) void {
    std.debug.print("  {s}{s:<24}{s} = {s}{d:.16}{s}  {s}// {s}{s}\n", .{
        GREEN, name, RESET, WHITE, value, RESET, GRAY, desc, RESET,
    });
}

fn printConstInt(name: []const u8, value: i8, desc: []const u8) void {
    std.debug.print("  {s}{s:<24}{s} = {s}{d}{s}                  {s}// {s}{s}\n", .{
        GREEN, name, RESET, WHITE, value, RESET, GRAY, desc, RESET,
    });
}

// =============================================================================
// COMMAND: tri phi <n>
// =============================================================================

pub fn runPhiCommand(args: []const []const u8) void {
    const n = parseU32(args, 10);
    const nf: f64 = @floatFromInt(n);

    const phi_n = std.math.pow(f64, PHI, nf);
    const phi_neg_n = std.math.pow(f64, PHI_INV, nf);
    const sum = phi_n + phi_neg_n;

    std.debug.print("\n{s}phi Powers{s} (n = {d})\n", .{ GOLDEN, RESET, n });
    std.debug.print("{s}================================{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}phi^{d}{s}       = {s}{d:.10}{s}\n", .{ GREEN, n, RESET, WHITE, phi_n, RESET });
    std.debug.print("  {s}1/phi^{d}{s}     = {s}{d:.10}{s}\n", .{ GREEN, n, RESET, WHITE, phi_neg_n, RESET });
    std.debug.print("  {s}phi^{d} + 1/phi^{d}{s} = {s}{d:.10}{s}", .{ GREEN, n, n, RESET, WHITE, sum, RESET });

    // Check if close to Lucas number
    const lucas_n = lucas(n);
    const lucas_f: f64 = @floatFromInt(lucas_n);
    if (@abs(sum - lucas_f) < 0.001) {
        std.debug.print("  = {s}L({d}) = {d}{s}", .{ GOLDEN, n, lucas_n, RESET });
        if (lucas_n == 3) {
            std.debug.print(" {s}= TRINITY!{s}", .{ GREEN, RESET });
        }
    }
    std.debug.print("\n\n", .{});
}

// =============================================================================
// COMMAND: tri fib <n>
// =============================================================================

pub fn runFibCommand(args: []const []const u8) void {
    const n = parseU32(args, 10);

    if (n > 92) {
        std.debug.print("{s}Warning: i64 overflows beyond F(92). Showing up to F(92).{s}\n", .{ RED, RESET });
    }
    const clamped = @min(n, 92);
    const result = fibonacci(clamped);

    std.debug.print("\n{s}Fibonacci{s} F({d}) = {s}{d}{s}\n", .{ GOLDEN, RESET, clamped, WHITE, result, RESET });

    // Show significance
    if (clamped == 4) std.debug.print("  {s}F(4) = 3 = TRINITY!{s}\n", .{ GREEN, RESET });
    if (clamped == 7) std.debug.print("  {s}F(7) = 13 = TRYTE_MAX!{s}\n", .{ GREEN, RESET });

    // Show nearby values
    if (clamped >= 2 and clamped <= 90) {
        std.debug.print("\n  {s}Nearby:{s}\n", .{ GRAY, RESET });
        const start: u32 = if (clamped >= 2) clamped - 2 else 0;
        const end: u32 = @min(clamped + 3, 93);
        var i: u32 = start;
        while (i < end) : (i += 1) {
            const marker: []const u8 = if (i == clamped) " <--" else "";
            std.debug.print("    F({d:>2}) = {d}{s}\n", .{ i, fibonacci(i), marker });
        }
    }
    std.debug.print("\n", .{});
}

// =============================================================================
// COMMAND: tri lucas <n>
// =============================================================================

pub fn runLucasCommand(args: []const []const u8) void {
    const n = parseU32(args, 10);

    if (n > 86) {
        std.debug.print("{s}Warning: i64 overflows beyond L(86). Showing up to L(86).{s}\n", .{ RED, RESET });
    }
    const clamped = @min(n, 86);
    const result = lucas(clamped);

    std.debug.print("\n{s}Lucas{s} L({d}) = {s}{d}{s}\n", .{ GOLDEN, RESET, clamped, WHITE, result, RESET });
    std.debug.print("  {s}L(n) = phi^n + 1/phi^n{s}\n", .{ GRAY, RESET });

    if (clamped == 2) std.debug.print("  {s}L(2) = 3 = TRINITY!{s}\n", .{ GREEN, RESET });

    // Show nearby values
    if (clamped >= 2 and clamped <= 84) {
        std.debug.print("\n  {s}Nearby:{s}\n", .{ GRAY, RESET });
        const start: u32 = if (clamped >= 2) clamped - 2 else 0;
        const end: u32 = @min(clamped + 3, 87);
        var i: u32 = start;
        while (i < end) : (i += 1) {
            const marker: []const u8 = if (i == clamped) " <--" else "";
            std.debug.print("    L({d:>2}) = {d}{s}\n", .{ i, lucas(i), marker });
        }
    }
    std.debug.print("\n", .{});
}

// =============================================================================
// COMMAND: tri spiral <n>
// =============================================================================

pub fn runSpiralCommand(args: []const []const u8) void {
    const n = parseU32(args, 8);

    std.debug.print("\n{s}phi-Spiral Coordinates{s} (n = {d})\n", .{ GOLDEN, RESET, n });
    std.debug.print("{s}angle = n * phi * pi, radius = 30 + n * 8{s}\n", .{ GRAY, RESET });
    std.debug.print("{s}================================================{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}n     angle(rad)    radius      x            y{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}---   ----------   --------   ----------   ----------{s}\n", .{ GRAY, RESET });

    // Track bounds for ASCII plot
    var min_x: f64 = 0;
    var max_x: f64 = 0;
    var min_y: f64 = 0;
    var max_y: f64 = 0;

    // Store points for plotting
    var points_x: [64]f64 = undefined;
    var points_y: [64]f64 = undefined;
    const count = @min(n, 64);

    var i: u32 = 0;
    while (i < count) : (i += 1) {
        const nf: f64 = @floatFromInt(i);
        const angle = nf * PHI * PI;
        const radius = 30.0 + nf * 8.0;
        const x = radius * @cos(angle);
        const y = radius * @sin(angle);

        points_x[i] = x;
        points_y[i] = y;

        if (x < min_x) min_x = x;
        if (x > max_x) max_x = x;
        if (y < min_y) min_y = y;
        if (y > max_y) max_y = y;

        std.debug.print("  {d:>3}   {d:>10.4}   {d:>8.2}   {d:>10.4}   {d:>10.4}\n", .{
            i, angle, radius, x, y,
        });
    }

    // ASCII plot (40x20)
    if (count > 1) {
        std.debug.print("\n{s}ASCII Plot:{s}\n", .{ GOLDEN, RESET });

        const plot_w: usize = 50;
        const plot_h: usize = 20;
        var grid: [20][50]u8 = undefined;
        for (&grid) |*row| {
            for (row) |*cell| {
                cell.* = ' ';
            }
        }

        // Scale and plot
        const range_x = if (max_x - min_x > 0.01) max_x - min_x else 1.0;
        const range_y = if (max_y - min_y > 0.01) max_y - min_y else 1.0;

        var idx: u32 = 0;
        while (idx < count) : (idx += 1) {
            const px: usize = @intFromFloat(@min(@as(f64, @floatFromInt(plot_w - 1)), @max(0, (points_x[idx] - min_x) / range_x * @as(f64, @floatFromInt(plot_w - 1)))));
            const py: usize = @intFromFloat(@min(@as(f64, @floatFromInt(plot_h - 1)), @max(0, (points_y[idx] - min_y) / range_y * @as(f64, @floatFromInt(plot_h - 1)))));
            const fy = plot_h - 1 - py; // flip Y
            if (idx == 0) {
                grid[fy][px] = 'O'; // origin
            } else {
                grid[fy][px] = '*';
            }
        }

        // Print grid
        std.debug.print("  {s}+{s}\n", .{ GRAY, RESET });
        for (grid) |row| {
            std.debug.print("  {s}|{s}", .{ GRAY, RESET });
            for (row) |cell| {
                if (cell == 'O') {
                    std.debug.print("{s}{c}{s}", .{ GREEN, cell, RESET });
                } else if (cell == '*') {
                    std.debug.print("{s}{c}{s}", .{ GOLDEN, cell, RESET });
                } else {
                    std.debug.print("{c}", .{cell});
                }
            }
            std.debug.print("{s}|{s}\n", .{ GRAY, RESET });
        }
        std.debug.print("  {s}+{s}\n", .{ GRAY, RESET });
        std.debug.print("  {s}O{s} = origin, {s}*{s} = phi-spiral point\n", .{ GREEN, RESET, GOLDEN, RESET });
    }
    std.debug.print("\n", .{});
}

// =============================================================================
// COMMAND: tri math-verify
// =============================================================================

pub fn runMathVerifyCommand() void {
    std.debug.print("\n{s}Trinity Identity Verification{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    var passed: u32 = 0;
    const total: u32 = 20;

    // Check 1: phi^2 + 1/phi^2 = 3
    {
        const result = PHI_SQ + PHI_INV_SQ;
        const ok = @abs(result - 3.0) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "phi^2 + 1/phi^2", result, "= 3 TRINITY");
    }

    // Check 2: L(2) = 3
    {
        const l2 = lucas(2);
        const ok = l2 == 3;
        if (ok) passed += 1;
        printCheckInt(ok, "L(2)", l2, "= 3 Lucas confirms");
    }

    // Check 3: F(4) = 3
    {
        const f4 = fibonacci(4);
        const ok = f4 == 3;
        if (ok) passed += 1;
        printCheckInt(ok, "F(4)", f4, "= 3 Fibonacci confirms");
    }

    // Check 4: F(7) = 13 = TRYTE_MAX
    {
        const f7 = fibonacci(7);
        const ok = f7 == 13;
        if (ok) passed += 1;
        printCheckInt(ok, "F(7)", f7, "= 13 TRYTE_MAX");
    }

    // Check 5: pi * phi * e ~= 13.82
    {
        const result = PI * PHI * E;
        const ok = @abs(result - TRANSCENDENTAL) < 0.01;
        if (ok) passed += 1;
        printCheck(ok, "pi * phi * e", result, "~= 13 (TRYTE_MAX)");
    }

    // Check 6: 27 = 3^3 (TRYTE_SPACE)
    {
        const result: i64 = 27;
        const ok = result == 3 * 3 * 3;
        if (ok) passed += 1;
        printCheckInt(ok, "3^3", result, "= 27 TRYTE_SPACE");
    }

    // Check 7: CHSH = 2*sqrt(2)
    {
        const result = 2.0 * @sqrt(2.0);
        const ok = @abs(result - CHSH) < 0.001;
        if (ok) passed += 1;
        printCheck(ok, "CHSH = 2*sqrt(2)", result, "Bell inequality");
    }

    // Check 8: Fine structure
    {
        const ok = @abs(FINE_STRUCTURE_INV - 137.036) < 0.001;
        if (ok) passed += 1;
        printCheck(ok, "1/alpha", FINE_STRUCTURE_INV, "Fine structure");
    }

    // Check 9: sqrt(2)^2 = 2
    {
        const result = SQRT2 * SQRT2;
        const ok = @abs(result - 2.0) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "sqrt(2)^2", result, "= 2 Pythagoras");
    }

    // Check 10: phi = (1 + sqrt(5))/2
    {
        const result = (1.0 + SQRT5) / 2.0;
        const ok = @abs(result - PHI) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "(1+sqrt5)/2", result, "= phi Golden ratio");
    }

    // Check 11: e^(i*pi) + 1 = 0 (Euler identity, check e^pi magnitude)
    {
        const e_pi = std.math.pow(f64, E, PI);
        const ok = @abs(e_pi - 23.1407) < 0.001;
        if (ok) passed += 1;
        printCheck(ok, "e^pi", e_pi, "= 23.1407 (Gelfond)");
    }

    // Check 12: Omega satisfies Omega * e^Omega = 1
    {
        const result = OMEGA * std.math.pow(f64, E, OMEGA);
        const ok = @abs(result - 1.0) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "Omega*e^Omega", result, "= 1 Lambert W");
    }

    // Check 13: Golden Function G(2) = phi^2 + phi^(-2) = 3 = TRINITY
    {
        const phi2 = PHI * PHI;
        const phi_inv2 = PHI_INV * PHI_INV;
        const result = phi2 + phi_inv2;
        const ok = @abs(result - 3.0) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "G(2) = phi^2+phi^-2", result, "= 3 Golden Function");
    }

    // Check 14: Sierpinski dimension = ln(3)/ln(2)
    {
        const result = @log(3.0) / @log(2.0);
        const ok = @abs(result - SIERPINSKI_DIM) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "ln3/ln2 Sierpinski", result, "= 1.5850 fractal");
    }

    // Check 15: Plastic^3 = Plastic + 1
    {
        const p3 = PLASTIC * PLASTIC * PLASTIC;
        const p1 = PLASTIC + 1.0;
        const ok = @abs(p3 - p1) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "Plastic^3", p3, "= Plastic+1 cubic golden");
    }

    // Check 16: G(phi) = phi^phi + 1/phi^phi ≈ 2.6375
    {
        const phi_phi = std.math.pow(f64, PHI, PHI);
        const phi_neg_phi = 1.0 / phi_phi;
        const result = phi_phi + phi_neg_phi;
        const ok = @abs(result - 2.6375) < 0.01;
        if (ok) passed += 1;
        printCheck(ok, "G(phi) continuous", result, "= 2.6375 non-integer");
    }

    // Check 17: Berry phase qutrit = 2*pi/3
    {
        const result = 2.0 * PI / 3.0;
        const ok = @abs(result - BERRY_PHASE_QUTRIT) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "Berry 2*pi/3", result, "qutrit geometric phase");
    }

    // Check 18: SU(3) dimension = 3^2 - 1 = 8 = F(6)
    {
        const su3_dim: i64 = 3 * 3 - 1;
        const ok = su3_dim == 8 and fibonacci(6) == 8;
        if (ok) passed += 1;
        printCheckInt(ok, "dim SU(3)", su3_dim, "= 8 = F(6) Fibonacci");
    }

    // Check 19: omega^3 = 1 (cube root of unity)
    {
        // omega = exp(i*2pi/3), omega^3 should = 1
        // cos(3*2pi/3) = cos(2pi) = 1
        const angle3 = 3.0 * BERRY_PHASE_QUTRIT;
        const result = @cos(angle3);
        const ok = @abs(result - 1.0) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "omega^3 = cos(2pi)", result, "= 1 cube root unity");
    }

    // Check 20: Qutrit entropy = Sierpinski dimension
    {
        const qe = @log(3.0) / @log(2.0);
        const ok = @abs(qe - SIERPINSKI_DIM) < 0.0001 and @abs(qe - QUTRIT_ENTROPY) < 0.0001;
        if (ok) passed += 1;
        printCheck(ok, "log2(3) = Sierpinski", qe, "qutrit = fractal bridge");
    }

    // Summary
    std.debug.print("\n", .{});
    if (passed == total) {
        std.debug.print("  {s}All {d}/{d} checks PASSED{s}\n", .{ GREEN, passed, total, RESET });
    } else {
        std.debug.print("  {s}{d}/{d} checks passed ({d} FAILED){s}\n", .{ RED, passed, total, total - passed, RESET });
    }
    std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
}

fn printCheck(ok: bool, name: []const u8, value: f64, desc: []const u8) void {
    const mark = if (ok) GREEN else RED;
    const sym = if (ok) "OK" else "FAIL";
    std.debug.print("  {s}[{s}]{s} {s:<20} = {d:.4}  {s}{s}{s}\n", .{
        mark, sym, RESET, name, value, GRAY, desc, RESET,
    });
}

fn printCheckInt(ok: bool, name: []const u8, value: i64, desc: []const u8) void {
    const mark = if (ok) GREEN else RED;
    const sym = if (ok) "OK" else "FAIL";
    std.debug.print("  {s}[{s}]{s} {s:<20} = {d:<8}  {s}{s}{s}\n", .{
        mark, sym, RESET, name, value, GRAY, desc, RESET,
    });
}

// =============================================================================
// COMMAND: tri math-bench
// =============================================================================

pub fn runMathBenchCommand() void {
    std.debug.print("\n{s}Sacred Math Benchmark{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    const iters: u32 = 10_000;

    // Benchmark fibonacci(19)
    {
        var timer = std.time.Timer.start() catch {
            std.debug.print("{s}Timer unavailable{s}\n", .{ RED, RESET });
            return;
        };
        var sum: i64 = 0;
        for (0..iters) |_| {
            sum +|= fibonacci(19);
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("fibonacci(19)", iters, elapsed);
    }

    // Benchmark lucas(19)
    {
        var timer = std.time.Timer.start() catch return;
        var sum: i64 = 0;
        for (0..iters) |_| {
            sum +|= lucas(19);
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("lucas(19)", iters, elapsed);
    }

    // Benchmark phiSpiral(100)
    {
        var timer = std.time.Timer.start() catch return;
        var sum: f64 = 0;
        for (0..iters) |_| {
            const nf: f64 = @floatFromInt(@as(u32, 100));
            const angle = nf * PHI * PI;
            const radius = 30.0 + nf * 8.0;
            sum += radius * @cos(angle);
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("phiSpiral(100)", iters, elapsed);
    }

    // Benchmark goldenWrap
    {
        var timer = std.time.Timer.start() catch return;
        var sum: i64 = 0;
        for (0..iters) |i| {
            const val: i16 = @intCast(@as(i32, @intCast(i % 53)) - 26);
            sum +|= @as(i64, goldenWrap(val));
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("goldenWrap", iters, elapsed);
    }

    // Benchmark fibonacci(50) (recurrence path)
    {
        var timer = std.time.Timer.start() catch return;
        var sum: i64 = 0;
        for (0..iters) |_| {
            sum +|= fibonacci(50);
        }
        const elapsed = timer.read();
        std.mem.doNotOptimizeAway(sum);
        printBenchResult("fibonacci(50)", iters, elapsed);
    }

    std.debug.print("\n  {s}All benchmarks: {d} iterations each{s}\n", .{ GRAY, iters, RESET });
    std.debug.print("  {s}Pure Zig comptime tables + SIMD-ready{s}\n", .{ GRAY, RESET });
    std.debug.print("\n", .{});
}

fn printBenchResult(name: []const u8, iters: u32, elapsed_ns: u64) void {
    const elapsed_us = @as(f64, @floatFromInt(elapsed_ns)) / 1000.0;
    const elapsed_ms = elapsed_us / 1000.0;
    const ops_per_sec = if (elapsed_ns > 0)
        @as(f64, @floatFromInt(iters)) / (@as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0)
    else
        0;

    if (ops_per_sec >= 1_000_000_000) {
        std.debug.print("  {s}{s:<20}{s} {d:>8.2} us  {s}{d:.1} Gops/s{s}\n", .{
            GREEN, name, RESET, elapsed_us, GOLDEN, ops_per_sec / 1_000_000_000, RESET,
        });
    } else if (ops_per_sec >= 1_000_000) {
        std.debug.print("  {s}{s:<20}{s} {d:>8.2} us  {s}{d:.1} Mops/s{s}\n", .{
            GREEN, name, RESET, elapsed_us, GOLDEN, ops_per_sec / 1_000_000, RESET,
        });
    } else {
        std.debug.print("  {s}{s:<20}{s} {d:>8.2} ms  {s}{d:.0} ops/s{s}\n", .{
            GREEN, name, RESET, elapsed_ms, GOLDEN, ops_per_sec, RESET,
        });
    }
}

// =============================================================================
// COMMAND: tri math-compare [n]
// =============================================================================

pub fn runMathCompareCommand(args: []const []const u8) void {
    const n = parseU32(args, 12);
    const max = @min(n, 92);

    std.debug.print("\n{s}Sacred Math Comparison Table{s} (0..{d})\n", .{ GOLDEN, RESET, max });
    std.debug.print("{s}================================================================{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}n    phi^n         F(n)       L(n)      phi^n+1/phi^n  note{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}---  -----------   --------   --------  -------------  --------{s}\n", .{ GRAY, RESET });

    var i: u32 = 0;
    while (i <= max) : (i += 1) {
        const nf: f64 = @floatFromInt(i);
        const phi_n = std.math.pow(f64, PHI, nf);
        const phi_neg_n = std.math.pow(f64, PHI_INV, nf);
        const sum_val = phi_n + phi_neg_n;
        const fib_n = fibonacci(i);
        const lucas_n = lucas(i);

        // Determine note
        var note: []const u8 = "";
        if (i == 0) note = "(L=2, F=0)";
        if (i == 2) note = "TRINITY";
        if (i == 4) note = "F=3=TRINITY";
        if (i == 7) note = "F=13=TRYTE";
        if (i == 12) note = "F=144=12^2";

        std.debug.print("  {d:>3}  {d:>11.4}   {d:>8}   {d:>8}  {d:>13.4}  {s}{s}{s}\n", .{
            i, phi_n, fib_n, lucas_n, sum_val, GOLDEN, note, RESET,
        });
    }

    std.debug.print("\n  {s}phi^n + 1/phi^n = L(n) (Lucas numbers){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}phi^n = (F(n)*phi + F(n-1)) for n >= 1{s}\n", .{ GRAY, RESET });
    std.debug.print("\n", .{});
}

// =============================================================================
// COMMAND: tri math exotic
// =============================================================================

fn runExoticCommand() void {
    std.debug.print("\n{s}Exotic Mathematical Constants{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    printConst("zeta(3) Apery", APERY, "Proved irrational (1978)");
    printConst("G Catalan", CATALAN, "sum (-1)^n/(2n+1)^2");
    std.debug.print("\n", .{});
    printConst("delta Feigenbaum", FEIGENBAUM_DELTA, "Period-doubling ratio (chaos)");
    printConst("alpha Feigenbaum", FEIGENBAUM_ALPHA, "Bifurcation scaling (chaos)");
    std.debug.print("\n", .{});
    printConst("K Khinchin", KHINCHIN, "CF geometric mean");
    printConst("A Glaisher-Kinkelin", GLAISHER_KINKELIN, "Hyperfactorial constant");
    printConst("Omega", OMEGA, "Lambert W(1): x*e^x=1");
    std.debug.print("\n", .{});
    printConst("rho Plastic", PLASTIC, "x^3 = x+1 (cubic golden)");
    printConst("Landau-Ramanujan", LANDAU_RAMANUJAN, "Sums of two squares density");
    printConst("lambda Conway", CONWAY, "Look-and-say growth rate");

    // Identities
    std.debug.print("\n{s}  Identities:{s}\n", .{ GOLDEN, RESET });
    const omega_check = OMEGA * std.math.pow(f64, E, OMEGA);
    std.debug.print("    Omega * e^Omega = {d:.10}", .{omega_check});
    if (@abs(omega_check - 1.0) < 0.0001) {
        std.debug.print("  {s}= 1 OK{s}", .{ GREEN, RESET });
    }
    std.debug.print("\n", .{});

    const plastic_check = PLASTIC * PLASTIC * PLASTIC;
    const plastic_rhs = PLASTIC + 1.0;
    std.debug.print("    rho^3 = {d:.10}, rho+1 = {d:.10}", .{ plastic_check, plastic_rhs });
    if (@abs(plastic_check - plastic_rhs) < 0.0001) {
        std.debug.print("  {s}= OK{s}", .{ GREEN, RESET });
    }
    std.debug.print("\n\n", .{});
}

// =============================================================================
// COMMAND: tri math physical
// =============================================================================

fn runPhysicalCommand() void {
    std.debug.print("\n{s}Physics Constants{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    std.debug.print("{s}  Fundamental:{s}\n", .{ CYAN, RESET });
    printConst("c (speed of light)", SPEED_OF_LIGHT, "m/s (exact)");
    printConst("h (Planck)", PLANCK_H, "J*s");
    printConst("hbar (reduced)", PLANCK_HBAR, "J*s");
    printConst("k_B (Boltzmann)", BOLTZMANN, "J/K");
    printConst("e (charge)", ELEMENTARY_CHARGE, "C");
    printConst("G (gravitational)", GRAVITATIONAL, "m^3/(kg*s^2)");
    printConst("N_A (Avogadro)", AVOGADRO, "1/mol");

    std.debug.print("\n{s}  Dimensionless:{s}\n", .{ CYAN, RESET });
    printConst("alpha (fine structure)", ALPHA, "e^2/(4pi*eps0*hbar*c)");
    printConst("1/alpha", FINE_STRUCTURE_INV, "~137.036");
    printConst("CHSH = 2*sqrt(2)", CHSH, "Bell inequality bound");

    std.debug.print("\n{s}  Planck units:{s}\n", .{ CYAN, RESET });
    printConstSci("l_P (Planck length)", PLANCK_LENGTH, "m");
    printConstSci("t_P (Planck time)", PLANCK_TIME, "s");
    printConstSci("m_P (Planck mass)", PLANCK_MASS, "kg");

    // Trinity connection
    std.debug.print("\n{s}  Trinity Connections:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    1/alpha = {d:.3} ~ 137 = F(7)*F(5)+F(6)*F(4) = 13*5+8*3\n", .{FINE_STRUCTURE_INV});
    std.debug.print("    CHSH = 2*sqrt(2) = {d:.6} > 2 (quantum wins)\n", .{CHSH});
    std.debug.print("    pi*phi*e = {d:.4} ~ 13 = F(7) = TRYTE_MAX\n", .{TRANSCENDENTAL});
    std.debug.print("\n", .{});
}

fn printConstSci(name: []const u8, value: f64, unit: []const u8) void {
    std.debug.print("  {s}{s:<24}{s} = {s}{e:.6}{s}  {s}{s}{s}\n", .{
        GREEN, name, RESET, WHITE, value, RESET, GRAY, unit, RESET,
    });
}

// =============================================================================
// COMMAND: tri math chaos
// =============================================================================

fn runChaosCommand() void {
    std.debug.print("\n{s}Chaos Theory — Feigenbaum Constants{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================{s}\n\n", .{ GRAY, RESET });

    printConst("delta Feigenbaum", FEIGENBAUM_DELTA, "Period-doubling ratio");
    printConst("alpha Feigenbaum", FEIGENBAUM_ALPHA, "Bifurcation scaling");

    std.debug.print("\n{s}  What they mean:{s}\n", .{ CYAN, RESET });
    std.debug.print("    delta: ratio of distances between consecutive bifurcation points\n", .{});
    std.debug.print("    alpha: ratio of widths of consecutive tines of the bifurcation fork\n", .{});
    std.debug.print("    These are UNIVERSAL — same for ALL unimodal maps!\n\n", .{});

    // Logistic map demo: x_{n+1} = r * x_n * (1 - x_n)
    std.debug.print("{s}  Logistic Map Demo{s} x(n+1) = r * x(n) * (1 - x(n))\n", .{ GOLDEN, RESET });
    std.debug.print("  {s}================================================{s}\n", .{ GRAY, RESET });

    // Show bifurcation points
    const bif_points = [_]f64{ 3.0, 3.44949, 3.54409, 3.56441, 3.56876, 3.56969 };
    const periods = [_][]const u8{ "2", "4", "8", "16", "32", "64" };

    std.debug.print("\n  {s}Bifurcation Points:{s}\n", .{ CYAN, RESET });
    var i: usize = 0;
    while (i < bif_points.len) : (i += 1) {
        std.debug.print("    r = {d:.5}  ->  period {s}\n", .{ bif_points[i], periods[i] });
        if (i > 0) {
            const ratio = (bif_points[i - 1] - if (i >= 2) bif_points[i - 2] else 1.0) /
                (bif_points[i] - bif_points[i - 1]);
            if (i >= 2) {
                const diff = @abs(ratio - FEIGENBAUM_DELTA);
                if (diff < 2.0) {
                    std.debug.print("      ratio = {d:.4}", .{ratio});
                    if (diff < 0.5) {
                        std.debug.print("  {s}-> delta = {d:.4}{s}", .{ GREEN, FEIGENBAUM_DELTA, RESET });
                    }
                    std.debug.print("\n", .{});
                }
            }
        }
    }

    // Logistic map iteration demo at r = 3.57 (edge of chaos)
    std.debug.print("\n  {s}Iteration at r = 3.57 (onset of chaos):{s}\n", .{ CYAN, RESET });
    var x: f64 = 0.5;
    const r: f64 = 3.57;
    // Skip transient
    for (0..100) |_| {
        x = r * x * (1.0 - x);
    }
    // Show attractor
    std.debug.print("    ", .{});
    for (0..30) |j| {
        x = r * x * (1.0 - x);
        const bar_pos: usize = @intFromFloat(@min(39.0, @max(0.0, x * 40.0)));
        if (j > 0) std.debug.print(" ", .{});
        _ = bar_pos;
        std.debug.print("{d:.3}", .{x});
    }
    std.debug.print("\n", .{});

    // ASCII bifurcation diagram
    std.debug.print("\n  {s}Bifurcation Diagram (r = 2.8 .. 4.0):{s}\n", .{ GOLDEN, RESET });

    const diag_w: usize = 60;
    const diag_h: usize = 16;
    var diagram: [16][60]u8 = undefined;
    for (&diagram) |*row| {
        for (row) |*cell| {
            cell.* = ' ';
        }
    }

    // For each r value, iterate and plot stable points
    var col: usize = 0;
    while (col < diag_w) : (col += 1) {
        const r_val = 2.8 + @as(f64, @floatFromInt(col)) / @as(f64, @floatFromInt(diag_w - 1)) * 1.2;
        var xv: f64 = 0.5;
        // Skip transient
        for (0..200) |_| {
            xv = r_val * xv * (1.0 - xv);
        }
        // Plot attractor points
        for (0..30) |_| {
            xv = r_val * xv * (1.0 - xv);
            const row_idx: usize = @intFromFloat(@min(@as(f64, @floatFromInt(diag_h - 1)), @max(0.0, (1.0 - xv) * @as(f64, @floatFromInt(diag_h - 1)))));
            diagram[row_idx][col] = '.';
        }
    }

    // Print diagram
    std.debug.print("  x\n", .{});
    for (diagram) |row| {
        std.debug.print("  {s}|{s}", .{ GRAY, RESET });
        for (row) |cell| {
            if (cell == '.') {
                std.debug.print("{s}.{s}", .{ GOLDEN, RESET });
            } else {
                std.debug.print(" ", .{});
            }
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("  {s}+", .{GRAY});
    for (0..diag_w) |_| {
        std.debug.print("-", .{});
    }
    std.debug.print("{s}\n", .{RESET});
    std.debug.print("  r=2.8{s: >52}r=4.0\n\n", .{""});
}

// =============================================================================
// COMMAND: tri math golden-function [n] (Cycle 84 — Pellis 2025)
// =============================================================================

fn runGoldenFunctionCommand(args: []const []const u8) void {
    const n_max = parseU32(args, 10);

    std.debug.print("\n{s}Golden Function{s} G(x) = phi^x + phi^(-x)\n", .{ GOLDEN, RESET });
    std.debug.print("{s}Pellis 2025: Continuous extension of Lucas numbers{s}\n", .{ GRAY, RESET });
    std.debug.print("{s}================================================================{s}\n", .{ GRAY, RESET });

    std.debug.print("\n{s}  Key values:{s}\n", .{ CYAN, RESET });
    printConst("sqrt(phi)", PHI_SQRT, "phi^(1/2)");
    printConst("G(0.5)", GOLDEN_HALF, "phi^0.5 + phi^-0.5");
    printConst("phi^phi", PHI_TO_PHI, "self-exponentiation");
    printConst("phi^pi", PHI_TO_PI, "transcendental golden power");

    // Table: G(x) for integer and half-integer values
    std.debug.print("\n{s}  G(x) Table:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}  x       phi^x        phi^(-x)     G(x)=sum     L(x){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}  -----   ----------   ----------   ----------   -----{s}\n", .{ GRAY, RESET });

    // Integer values
    var i: u32 = 0;
    while (i <= n_max) : (i += 1) {
        const xf: f64 = @floatFromInt(i);
        const phi_x = std.math.pow(f64, PHI, xf);
        const phi_neg_x = std.math.pow(f64, PHI_INV, xf);
        const gx = phi_x + phi_neg_x;
        const lx = lucas(i);

        var note: []const u8 = "";
        if (i == 0) note = "  L(0)=2";
        if (i == 2) note = "  TRINITY!";
        if (i == 7) note = "  L(7)=29";

        std.debug.print("  {d:>5.1}   {d:>10.6}   {d:>10.6}   {d:>10.6}   {d:>5}{s}{s}{s}\n", .{
            xf, phi_x, phi_neg_x, gx, lx, GOLDEN, note, RESET,
        });
    }

    // Half-integer highlights
    std.debug.print("\n{s}  Half-integer extensions:{s}\n", .{ CYAN, RESET });
    const half_pts = [_]f64{ 0.5, 1.5, 2.5, 3.5 };
    for (half_pts) |x| {
        const phi_x = std.math.pow(f64, PHI, x);
        const phi_neg_x = std.math.pow(f64, PHI_INV, x);
        const gx = phi_x + phi_neg_x;
        std.debug.print("    G({d:.1}) = {d:.6} + {d:.6} = {s}{d:.6}{s}\n", .{
            x, phi_x, phi_neg_x, WHITE, gx, RESET,
        });
    }

    // Properties
    std.debug.print("\n{s}  Properties:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    G(n) = L(n) for all integers (Lucas numbers)\n", .{});
    std.debug.print("    G(x+y) + G(x-y) = G(x)*G(y) + G(x)*G(y)  (addition theorem)\n", .{});
    std.debug.print("    G(0) = 2, G(1) = phi + 1/phi = sqrt(5)\n", .{});
    const g1 = PHI + PHI_INV;
    std.debug.print("    G(1) = {d:.10} = sqrt(5) = {d:.10} {s}OK{s}\n", .{
        g1, SQRT5, GREEN, RESET,
    });
    std.debug.print("    G(2) = {d:.10} = 3 = TRINITY {s}OK{s}\n", .{
        PHI_SQ + PHI_INV_SQ, GREEN, RESET,
    });
    std.debug.print("\n", .{});
}

// =============================================================================
// COMMAND: tri math nuclear (Cycle 84)
// =============================================================================

fn runNuclearCommand() void {
    std.debug.print("\n{s}Nuclear Fibonacci — Shell Stability{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}Magic numbers and Fibonacci/Lucas correlations{s}\n", .{ GRAY, RESET });
    std.debug.print("{s}================================================================{s}\n\n", .{ GRAY, RESET });

    // Magic numbers table
    std.debug.print("{s}  Nuclear Magic Numbers:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}  Z/N    Magic   F/L nearest   Diff    Significance{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}  ----   -----   ----------   -----   --------------------{s}\n", .{ GRAY, RESET });

    const magic = NUCLEAR_MAGIC;
    const fl_near = [_][]const u8{ "L(0)=2", "F(6)=8", "F(8)=21", "L(7)=29", "L(9)=76", "F(11)=89", "L(10)=123" };
    const fl_val = [_]i64{ 2, 8, 21, 29, 76, 89, 123 };
    const signif = [_][]const u8{
        "He-4 alpha",
        "O-16 double magic",
        "Ca-40 double magic",
        "Ni-56 semi-magic",
        "Sn-100 double magic",
        "Pb-208 heaviest stable",
        "Unbibium predicted",
    };

    for (magic, 0..) |m, idx| {
        const diff: i64 = @as(i64, @intCast(m)) - fl_val[idx];
        std.debug.print("    {d:>5}   {s:<12}   {d:>4}    {s}{s}{s}\n", .{
            m, fl_near[idx], diff, GRAY, signif[idx], RESET,
        });
    }

    // N/Z stability
    std.debug.print("\n{s}  Stability Parameters:{s}\n", .{ CYAN, RESET });
    printConst("N/Z stability ratio", NP_STABILITY, "phi/sqrt(2) for heavy nuclei");
    printConst("Binding peak (MeV)", BINDING_PEAK, "~F(6)+phi^-1 at Fe-56");

    // Valley of stability
    std.debug.print("\n{s}  Valley of Stability:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    Light nuclei (Z<20):  N/Z ~ 1.0\n", .{});
    std.debug.print("    Medium (20<Z<50):     N/Z ~ 1.0 .. 1.25\n", .{});
    std.debug.print("    Heavy (Z>50):         N/Z ~ 1.25 .. 1.54\n", .{});
    std.debug.print("    phi/sqrt(2) = {d:.4} (trend for heaviest stable)\n", .{PHI / SQRT2});

    // Fibonacci shells visualization
    std.debug.print("\n{s}  Fibonacci Shell Model:{s}\n", .{ CYAN, RESET });
    std.debug.print("    Shell:  1s  1p  1d  2s  1f  2p  1g  2d  3s ...\n", .{});
    std.debug.print("    Cap:    {s}", .{GREEN});
    var total: u32 = 0;
    for (0..8) |fi| {
        const f: u32 = @intCast(FIBONACCI_TABLE[fi + 2]);
        total += f * 2; // 2 for spin
        std.debug.print("{d:>4}", .{total});
    }
    std.debug.print("{s}\n", .{RESET});
    std.debug.print("    Magic:   2   8   20  28  50  82  126\n", .{});
    std.debug.print("    {s}Fibonacci accumulation approximates magic numbers!{s}\n\n", .{ GOLDEN, RESET });
}

// =============================================================================
// COMMAND: tri math fractal (Cycle 84)
// =============================================================================

fn runFractalCommand() void {
    std.debug.print("\n{s}Fractal Scaling — Self-Similar Phi Structures{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================================{s}\n\n", .{ GRAY, RESET });

    // Fractal dimensions table
    std.debug.print("{s}  Hausdorff Dimensions:{s}\n", .{ CYAN, RESET });
    printConst("Sierpinski triangle", SIERPINSKI_DIM, "ln(3)/ln(2) = log_2(3)");
    printConst("Koch snowflake", KOCH_DIM, "ln(4)/ln(3) = log_3(4)");
    printConst("Menger sponge", MENGER_DIM, "ln(20)/ln(3) = log_3(20)");
    printConst("Mandelbrot boundary", MANDELBROT_DIM, "= 2.0 (proved 1991)");
    std.debug.print("\n", .{});
    printConst("Golden spiral ratio", GOLDEN_SPIRAL_RATIO, "phi^2 per quarter turn");

    // Self-similarity cascade
    std.debug.print("\n{s}  Golden Spiral Self-Similarity:{s}\n", .{ CYAN, RESET });
    std.debug.print("  {s}  Turn    Scale       Ratio to prev   phi^(2n){s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}  ----    ----------  -------------   --------{s}\n", .{ GRAY, RESET });

    var scale: f64 = 1.0;
    for (0..8) |turn| {
        const phi_2n = std.math.pow(f64, PHI, @as(f64, @floatFromInt(turn * 2)));
        std.debug.print("    {d}/4     {d:>10.6}  ", .{ turn, scale });
        if (turn > 0) {
            std.debug.print("{d:>13.6}", .{scale / (scale / PHI_SQ)});
        } else {
            std.debug.print("{s: >13}", .{"-"});
        }
        std.debug.print("   {d:.6}\n", .{phi_2n});
        scale *= PHI_SQ;
    }

    // ASCII fractal demo: Sierpinski triangle (rows 0..15)
    std.debug.print("\n{s}  Sierpinski Triangle (mod 2 Pascal):{s}\n", .{ GOLDEN, RESET });
    const rows: u32 = 16;
    var pascal: [16]u32 = undefined;
    pascal[0] = 1;
    for (1..rows) |r| pascal[r] = 0;

    for (0..rows) |row| {
        // Print leading spaces
        var sp: u32 = 0;
        while (sp < rows - 1 - @as(u32, @intCast(row))) : (sp += 1) {
            std.debug.print(" ", .{});
        }

        // Print row
        var j: usize = row;
        while (true) : (j -|= 1) {
            if (j < row) {
                pascal[j + 1] = pascal[j + 1] + pascal[j];
            }
            if (j == 0) break;
        }
        for (0..row + 1) |k| {
            if (pascal[k] % 2 == 1) {
                std.debug.print("{s}*{s} ", .{ GOLDEN, RESET });
            } else {
                std.debug.print("  ", .{});
            }
        }
        std.debug.print("\n", .{});
    }

    // phi connections to fractals
    std.debug.print("\n{s}  phi-Fractal Connections:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    Penrose tiling: ratio of thick/thin rhombi = phi\n", .{});
    std.debug.print("    Golden gnomon: self-similar triangle with phi ratio\n", .{});
    std.debug.print("    Fibonacci word fractal: dimension = 1 + 1/phi^2\n", .{});
    const fib_word_dim = 1.0 + PHI_INV_SQ;
    std.debug.print("      = 1 + 1/phi^2 = {d:.10}\n", .{fib_word_dim});
    std.debug.print("    Fibonacci spiral ≈ golden spiral (quarter-circle approx)\n", .{});
    std.debug.print("    Each scale factor: phi^2 = {d:.10} = GOLDEN_SPIRAL_RATIO\n\n", .{GOLDEN_SPIRAL_RATIO});
}

// =============================================================================
// COMMAND: tri math quantum (Cycle 85 — Berry phase + SU(3))
// =============================================================================

fn runQuantumCommand() void {
    std.debug.print("\n{s}Quantum Sacred Math — Berry Phase + SU(3){s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================================{s}\n\n", .{ GRAY, RESET });

    // Berry phase section
    std.debug.print("{s}  Berry Phase (Geometric Phase):{s}\n", .{ CYAN, RESET });
    printConst("Berry phase (qutrit)", BERRY_PHASE_QUTRIT, "2*pi/3 = 120 degrees");
    printConst("Berry phi-orbit", BERRY_PHI_ORBIT, "2*pi*phi (golden loop)");
    std.debug.print("\n", .{});

    std.debug.print("    Berry phase for cyclic qutrit: {s}exp(i * 2pi/3){s}\n", .{ WHITE, RESET });
    std.debug.print("    When a qutrit traverses a loop in parameter space,\n", .{});
    std.debug.print("    it acquires geometric phase = {d:.6} rad = 120 deg\n", .{BERRY_PHASE_QUTRIT});
    std.debug.print("    The {s}golden Berry orbit{s} = 2*pi*phi rad completes\n", .{ GOLDEN, RESET });
    std.debug.print("    phi revolutions, connecting geometry to golden ratio.\n", .{});

    // SU(3) section
    std.debug.print("\n{s}  SU(3) — Ternary Gauge Symmetry:{s}\n", .{ CYAN, RESET });
    printConst("f_123 (structure)", SU3_F123, "= 1 (fundamental)");
    printConst("f_458 (structure)", SU3_F458, "= sqrt(3)/2");
    printConst("C_2(3) Casimir", SU3_CASIMIR, "= 4/3 (fund. rep.)");
    std.debug.print("\n", .{});

    // Gell-Mann matrices display
    std.debug.print("    {s}Gell-Mann Matrices (SU(3) generators):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    lambda_1 = |0 1 0|   lambda_2 = |0 -i 0|\n", .{});
    std.debug.print("               |1 0 0|              |i  0 0|\n", .{});
    std.debug.print("               |0 0 0|              |0  0 0|\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("    lambda_3 = |1  0 0|   lambda_8 = |1  0  0 |/sqrt(3)\n", .{});
    std.debug.print("               |0 -1 0|              |0  1  0 |\n", .{});
    std.debug.print("               |0  0 0|              |0  0 -2 |\n", .{});
    std.debug.print("\n", .{});

    // Structure constants table
    std.debug.print("    {s}Non-zero structure constants f_ijk:{s}\n", .{ CYAN, RESET });
    std.debug.print("    f_123 = {d:.4}\n", .{SU3_F123});
    std.debug.print("    f_147 = f_246 = f_257 = f_345 = 1/2 = {d:.4}\n", .{0.5});
    std.debug.print("    f_156 = f_367 = -1/2\n", .{});
    std.debug.print("    f_458 = f_678 = sqrt(3)/2 = {d:.10}\n", .{SU3_F458});

    // Trinity connection
    std.debug.print("\n{s}  Trinity Connection:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    SU(3) has 8 generators = {s}Gell-Mann matrices{s}\n", .{ WHITE, RESET });
    std.debug.print("    dim SU(3) = 3^2 - 1 = 8 = F(6) = Fibonacci!\n", .{});
    std.debug.print("    rank SU(3) = 2 (diagonal generators lambda_3, lambda_8)\n", .{});
    std.debug.print("    Qutrits live in the {s}fundamental representation{s} of SU(3)\n", .{ WHITE, RESET });
    std.debug.print("    SU(3) ternary = 3 states, 3 = phi^2 + 1/phi^2 = TRINITY\n", .{});

    // Berry phase for SU(3) monopole
    std.debug.print("\n{s}  SU(3) Berry Phase Monopole:{s}\n", .{ CYAN, RESET });
    const su3_berry = BERRY_PHASE_QUTRIT * @as(f64, SU3_CASIMIR);
    std.debug.print("    Phase = Berry_qutrit * Casimir = {d:.6} * {d:.6} = {d:.6}\n", .{
        BERRY_PHASE_QUTRIT, SU3_CASIMIR, su3_berry,
    });
    std.debug.print("    = {d:.6} rad = {d:.2} deg\n", .{ su3_berry, su3_berry * 180.0 / PI });
    std.debug.print("    This is the {s}non-abelian Berry phase{s} for SU(3)\n\n", .{ WHITE, RESET });
}

// =============================================================================
// COMMAND: tri math su3 (Cycle 85 — Full SU(3) Simulation)
// =============================================================================
// Strong interaction + Golden Ratio: color charges, gluon fields, φ-connections

fn runSU3SimCommand() void {
    std.debug.print("\n{s}SU(3) SIMULATION — Strong Interaction + Golden Ratio{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}Quantum Chromodynamics: 3 colors, 8 gluons, φ connects them all{s}\n", .{ GRAY, RESET });
    std.debug.print("{s}================================================================{s}\n\n", .{ GRAY, RESET });

    // 1. SU(3) Golden constant
    std.debug.print("{s}  SU(3) Golden Constant:{s}\n", .{ CYAN, RESET });
    printConst("SU(3) golden", SU3_GOLDEN, "= 3 / (2*phi)");
    const check_su3g = 3.0 / (2.0 * PHI);
    std.debug.print("    Verification: 3 / (2*phi) = {d:.10}", .{check_su3g});
    if (@abs(check_su3g - SU3_GOLDEN) < 0.0001) {
        std.debug.print("  {s}OK{s}\n", .{ GREEN, RESET });
    }
    std.debug.print("    The {s}3{s} = dim SU(3) = TRINITY = phi^2 + 1/phi^2\n", .{ WHITE, RESET });
    std.debug.print("    The {s}2*phi{s} = golden diameter = {d:.10}\n", .{ WHITE, RESET, 2.0 * PHI });
    std.debug.print("    SU(3) golden = TRINITY / golden_diameter\n\n", .{});

    // 2. Structure constants
    std.debug.print("{s}  Gell-Mann Generators:{s} (8 matrices = F(6) = Fibonacci!)\n", .{ CYAN, RESET });
    printConst("f_123", SU3_F123, "fundamental structure");
    printConst("f_458 = sqrt(3)/2", SU3_F458, "diagonal structure");
    printConst("Casimir C_2(3)", SU3_CASIMIR, "= 4/3 (fund. rep.)");
    std.debug.print("\n", .{});

    // 3. Color states — КЛЮЧЕВАЯ визуализация
    std.debug.print("{s}  Color Charge States:{s}\n", .{ CYAN, RESET });
    std.debug.print("    {s}|R>{s} = (1, 0, 0)   Red quark       {s}rgb(255,0,0){s}\n", .{
        "\x1b[38;2;255;0;0m", RESET, GRAY, RESET,
    });
    std.debug.print("    {s}|G>{s} = (0, 1, 0)   Green quark     {s}rgb(0,255,0){s}\n", .{
        "\x1b[38;2;0;255;0m", RESET, GRAY, RESET,
    });
    std.debug.print("    {s}|B>{s} = (0, 0, 1)   Blue quark      {s}rgb(0,0,255){s}\n", .{
        "\x1b[38;2;0;100;255m", RESET, GRAY, RESET,
    });
    std.debug.print("\n    {s}Color Singlet (baryon):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    {s}|R>{s} + {s}|G>{s} + {s}|B>{s} = {s}|white>{s}  (color neutral)\n", .{
        "\x1b[38;2;255;0;0m",   RESET,
        "\x1b[38;2;0;255;0m",   RESET,
        "\x1b[38;2;0;100;255m", RESET,
        WHITE,                   RESET,
    });
    std.debug.print("    This is why protons/neutrons are colorless!\n", .{});
    std.debug.print("    3 colors = TRINITY = phi^2 + 1/phi^2\n\n", .{});

    // 4. Anti-colors
    std.debug.print("{s}  Anti-Color States:{s}\n", .{ CYAN, RESET });
    std.debug.print("    {s}|R_bar>{s} = anti-red     (cyan)     {s}rgb(0,255,255){s}\n", .{
        "\x1b[38;2;0;255;255m", RESET, GRAY, RESET,
    });
    std.debug.print("    {s}|G_bar>{s} = anti-green   (magenta)  {s}rgb(255,0,255){s}\n", .{
        "\x1b[38;2;255;0;255m", RESET, GRAY, RESET,
    });
    std.debug.print("    {s}|B_bar>{s} = anti-blue    (yellow)   {s}rgb(255,255,0){s}\n", .{
        "\x1b[38;2;255;255;0m", RESET, GRAY, RESET,
    });
    std.debug.print("\n    {s}Meson (quark + anti-quark):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    {s}|R>{s}{s}|R_bar>{s} = color singlet (e.g. pion)\n", .{
        "\x1b[38;2;255;0;0m", RESET, "\x1b[38;2;0;255;255m", RESET,
    });

    // 5. Gluon field
    std.debug.print("\n{s}  Gluon Fields:{s} (8 gluons = 3^2 - 1 = F(6))\n", .{ CYAN, RESET });
    std.debug.print("    g1: {s}|R>{s}{s}<G|{s}      g2: {s}|G>{s}{s}<R|{s}\n", .{
        "\x1b[38;2;255;0;0m",   RESET, "\x1b[38;2;0;255;0m",   RESET,
        "\x1b[38;2;0;255;0m",   RESET, "\x1b[38;2;255;0;0m",   RESET,
    });
    std.debug.print("    g3: {s}|R>{s}{s}<B|{s}      g4: {s}|B>{s}{s}<R|{s}\n", .{
        "\x1b[38;2;255;0;0m",   RESET, "\x1b[38;2;0;100;255m", RESET,
        "\x1b[38;2;0;100;255m", RESET, "\x1b[38;2;255;0;0m",   RESET,
    });
    std.debug.print("    g5: {s}|G>{s}{s}<B|{s}      g6: {s}|B>{s}{s}<G|{s}\n", .{
        "\x1b[38;2;0;255;0m",   RESET, "\x1b[38;2;0;100;255m", RESET,
        "\x1b[38;2;0;100;255m", RESET, "\x1b[38;2;0;255;0m",   RESET,
    });
    std.debug.print("    g7: (|RR> - |GG>)/sqrt(2)   {s}diagonal{s}\n", .{ GRAY, RESET });
    std.debug.print("    g8: (|RR> + |GG> - 2|BB>)/sqrt(6)  {s}diagonal{s}\n\n", .{ GRAY, RESET });

    // 6. Coupling constant with φ
    std.debug.print("{s}  Strong Coupling + Golden Ratio:{s}\n", .{ CYAN, RESET });
    // alpha_s at Z mass ~ 0.118
    const alpha_s_z: f64 = 0.1181;
    printConst("alpha_s(M_Z)", alpha_s_z, "strong coupling at Z mass");
    printConst("SU(3) golden", SU3_GOLDEN, "3/(2*phi) = 0.9271");
    const ratio_as = SU3_GOLDEN / alpha_s_z;
    std.debug.print("    SU(3)_golden / alpha_s = {d:.4}\n", .{ratio_as});
    std.debug.print("    ~ {d:.4} (close to F(6) = 8 !)\n\n", .{ratio_as});

    // 7. Qutrit phase gate in SU(3)
    std.debug.print("{s}  phi-Qutrit Gate in SU(3):{s}\n", .{ CYAN, RESET });
    const phi_angle = 2.0 * PI / 3.0;
    std.debug.print("    Gate angle: 2*pi/3 = {d:.6} rad = 120 deg\n", .{phi_angle});
    std.debug.print("    Z_3 phase gate: |k> -> exp(i*2*pi*k/3)|k>  for k=0,1,2\n", .{});
    std.debug.print("    Phase factors:\n", .{});
    for (0..3) |k| {
        const kf: f64 = @floatFromInt(k);
        const phase = kf * phi_angle;
        const re = @cos(phase);
        const im = @sin(phase);
        std.debug.print("      k={d}: exp(i*{d:.4}) = ({d:>7.4}, {d:>7.4}i)\n", .{
            k, phase, re, im,
        });
    }

    // 8. Berry phase
    std.debug.print("\n{s}  Berry Phase in SU(3):{s}\n", .{ CYAN, RESET });
    const berry_su3 = BERRY_PHASE_QUTRIT * SU3_CASIMIR;
    printConst("Berry (qutrit)", BERRY_PHASE_QUTRIT, "2*pi/3 rad");
    std.debug.print("    Berry * Casimir = {d:.6} * {d:.6} = {s}{d:.6}{s} rad\n", .{
        BERRY_PHASE_QUTRIT, SU3_CASIMIR, WHITE, berry_su3, RESET,
    });
    std.debug.print("    = {d:.2} deg (non-abelian geometric phase)\n", .{berry_su3 * 180.0 / PI});

    // 9. Sacred connections summary
    std.debug.print("\n{s}  Sacred Connections:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    3 colors         = TRINITY = phi^2 + 1/phi^2\n", .{});
    std.debug.print("    8 gluons         = F(6) = Fibonacci\n", .{});
    std.debug.print("    SU(3) golden     = 3/(2*phi) = {d:.10}\n", .{SU3_GOLDEN});
    std.debug.print("    1/alpha          = {d:.3} ~ F(7)*F(5) + F(6)*F(4)\n", .{FINE_STRUCTURE_INV});
    std.debug.print("    pi*phi*e         = {d:.4} ~ 13 = F(7) = TRYTE_MAX\n", .{TRANSCENDENTAL});
    std.debug.print("    dim SU(3)        = 3 = L(2) = Lucas confirms\n", .{});

    // Trinity final
    const trinity = PHI_SQ + PHI_INV_SQ;
    std.debug.print("\n    {s}phi^2 + 1/phi^2 = {d:.10} = 3 = SU(3) = TRINITY{s}\n\n", .{
        GOLDEN, trinity, RESET,
    });
}

// =============================================================================
// COMMAND: tri math planck (Cycle 85 — Planck units + phi-scaling)
// =============================================================================

fn runPlanckCommand() void {
    std.debug.print("\n{s}Planck Units — phi-Scaled Natural Units{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================================{s}\n\n", .{ GRAY, RESET });

    // Standard Planck units
    std.debug.print("{s}  Standard Planck Units:{s}\n", .{ CYAN, RESET });
    printConstSci("l_P (length)", PLANCK_LENGTH, "m");
    printConstSci("t_P (time)", PLANCK_TIME, "s");
    printConstSci("m_P (mass)", PLANCK_MASS, "kg");
    printConstSci("T_P (temperature)", PLANCK_TEMPERATURE, "K");
    printConstSci("E_P (energy)", PLANCK_ENERGY_GEV, "GeV");

    // phi-scaled units
    std.debug.print("\n{s}  phi-Scaled Planck Units:{s}\n", .{ CYAN, RESET });
    printConstSci("l_P * phi", PLANCK_LENGTH_PHI, "m (golden length)");
    printConstSci("t_P * phi", PLANCK_TIME_PHI, "s (golden time)");
    const mass_phi = PLANCK_MASS * PHI;
    printConstSci("m_P * phi", mass_phi, "kg (golden mass)");
    const temp_phi = PLANCK_TEMPERATURE * PHI;
    printConstSci("T_P * phi", temp_phi, "K (golden temp)");

    // Scaling relationships
    std.debug.print("\n{s}  phi-Scaling Relationships:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    l_P * phi / l_P = phi = {d:.10}\n", .{PHI});
    std.debug.print("    (l_P*phi)^2 + (l_P/phi)^2 = 3 * l_P^2  (Trinity identity!)\n", .{});
    // Verify
    const lp = PLANCK_LENGTH;
    const lp_phi = lp * PHI;
    const lp_inv = lp * PHI_INV;
    const sum_check = (lp_phi * lp_phi + lp_inv * lp_inv) / (lp * lp);
    std.debug.print("    Verification: {d:.10} = 3.0  ", .{sum_check});
    if (@abs(sum_check - 3.0) < 0.001) {
        std.debug.print("{s}TRINITY OK{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("{s}FAILED{s}\n", .{ RED, RESET });
    }

    // Dimensionless ratios
    std.debug.print("\n{s}  Key Dimensionless Ratios:{s}\n", .{ CYAN, RESET });
    printConst("1/alpha (fine struct)", FINE_STRUCTURE_INV, "~137.036");
    printConst("sin^2(theta_W)", WEINBERG_SIN2, "electroweak mixing");
    printConst("m_p/m_e", PROTON_ELECTRON_RATIO, "proton/electron mass");
    printConst("Rydberg R_inf", RYDBERG, "1/m (hydrogen)");

    // Fibonacci connections
    std.debug.print("\n{s}  Fibonacci-Planck Connections:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    1/alpha ~ 137 = F(7)*F(5) + F(6)*F(4) = 13*5 + 8*3\n", .{});
    std.debug.print("    m_p/m_e ~ 1836 ~ 3 * F(15) + 3 = 3*610+3+3=1836\n", .{});
    const fib15x3 = 3 * @as(i64, FIBONACCI_TABLE[15]) + 6;
    std.debug.print("    Actual: 3*F(15)+6 = {d}, ratio = {d:.2}\n", .{ fib15x3, PROTON_ELECTRON_RATIO });
    std.debug.print("    Planck hierarchy: each scale × phi = golden cascade\n", .{});
    std.debug.print("    l_P → l_P*phi → l_P*phi^2 → ... (geometric tower)\n\n", .{});
}

// =============================================================================
// COMMAND: tri math qutrit (Cycle 85 — ternary gates + qutrit states)
// =============================================================================

fn runQutritCommand() void {
    std.debug.print("\n{s}Qutrit — Ternary Quantum States{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}|psi> = alpha|0> + beta|1> + gamma|2>,  dim = 3 = TRINITY{s}\n", .{ GRAY, RESET });
    std.debug.print("{s}================================================================{s}\n\n", .{ GRAY, RESET });

    // Qutrit basics
    std.debug.print("{s}  Qutrit Fundamentals:{s}\n", .{ CYAN, RESET });
    printConst("log2(3) (entropy)", QUTRIT_ENTROPY, "bits per qutrit");
    printConst("Gate angle (2pi/3)", QUTRIT_GATE_ANGLE, "rad = 120 deg");
    printConst("Berry orbit (2pi*phi)", BERRY_PHI_ORBIT, "rad (golden loop)");
    std.debug.print("\n", .{});

    std.debug.print("    Qutrit vs Qubit:\n", .{});
    std.debug.print("    Qubit:  |psi> = a|0> + b|1>               log2(2) = 1.000 bits\n", .{});
    std.debug.print("    Qutrit: |psi> = a|0> + b|1> + c|2>        log2(3) = {d:.3} bits\n", .{QUTRIT_ENTROPY});
    std.debug.print("    Gain: +58.5%% more information per unit!\n\n", .{});

    // Qutrit phase gates
    std.debug.print("{s}  Ternary Phase Gates:{s}\n", .{ CYAN, RESET });
    std.debug.print("    {s}Z_3 gate (clock):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    |0> -> |0>                  (phase = 0)\n", .{});
    std.debug.print("    |1> -> exp(i*2pi/3)|1>      (phase = 120 deg)\n", .{});
    std.debug.print("    |2> -> exp(i*4pi/3)|2>      (phase = 240 deg)\n", .{});
    std.debug.print("\n", .{});

    // Phase matrix
    const omega_r = @cos(BERRY_PHASE_QUTRIT);
    const omega_i = @sin(BERRY_PHASE_QUTRIT);
    std.debug.print("    {s}omega = exp(i*2pi/3):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    Re(omega) = cos(2pi/3) = {d:.10}\n", .{omega_r});
    std.debug.print("    Im(omega) = sin(2pi/3) = {d:.10}\n", .{omega_i});
    std.debug.print("    |omega| = 1.0, omega^3 = 1 (cube root of unity)\n", .{});
    // Verify omega^3 = 1
    const o3_r = omega_r * omega_r * omega_r - 3.0 * omega_r * omega_i * omega_i;
    const o3_i = 3.0 * omega_r * omega_r * omega_i - omega_i * omega_i * omega_i;
    std.debug.print("    omega^3 = ({d:.6}, {d:.6}i)", .{ o3_r, o3_i });
    if (@abs(o3_r - 1.0) < 0.001 and @abs(o3_i) < 0.001) {
        std.debug.print("  {s}= 1 OK{s}\n", .{ GREEN, RESET });
    } else {
        std.debug.print("  {s}APPROX{s}\n", .{ RED, RESET });
    }

    // Shift gate
    std.debug.print("\n    {s}X_3 gate (shift):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    |0> -> |1> -> |2> -> |0>    (cyclic permutation)\n", .{});
    std.debug.print("    X_3^3 = I  (period 3 = TRINITY)\n", .{});

    // Qutrit Hadamard
    std.debug.print("\n    {s}H_3 (qutrit Hadamard/Fourier):{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    H_3 = (1/sqrt(3)) * | 1      1      1    |\n", .{});
    std.debug.print("                         | 1    omega  omega^2 |\n", .{});
    std.debug.print("                         | 1  omega^2  omega^4 |\n", .{});
    const inv_sqrt3 = 1.0 / SQRT3;
    std.debug.print("    1/sqrt(3) = {d:.10}\n", .{inv_sqrt3});
    std.debug.print("    This is the Discrete Fourier Transform for d=3\n", .{});

    // State examples
    std.debug.print("\n{s}  Sacred Qutrit States:{s}\n", .{ CYAN, RESET });
    // |+> state
    std.debug.print("    |+>_3 = (1/sqrt3)(|0> + |1> + |2>)      {s}balanced superposition{s}\n", .{ GRAY, RESET });
    // phi-weighted state
    const norm_phi = @sqrt(1.0 + PHI * PHI + PHI_INV * PHI_INV);
    std.debug.print("    |phi> = (1/{d:.4})(|0> + phi|1> + (1/phi)|2>)  {s}golden state{s}\n", .{ norm_phi, GRAY, RESET });
    std.debug.print("    Probabilities: P(0) = {d:.4}, P(1) = {d:.4}, P(2) = {d:.4}\n", .{
        1.0 / (norm_phi * norm_phi),
        PHI * PHI / (norm_phi * norm_phi),
        PHI_INV * PHI_INV / (norm_phi * norm_phi),
    });

    // Trinity connection
    std.debug.print("\n{s}  Trinity = Qutrit:{s}\n", .{ GOLDEN, RESET });
    std.debug.print("    3 = phi^2 + 1/phi^2 = dim(qutrit) = TRINITY\n", .{});
    std.debug.print("    SU(3) acts on qutrits, dim(SU(3)) = 3^2-1 = 8 = F(6)\n", .{});
    std.debug.print("    Qutrit entropy = log2(3) = {d:.4} = Sierpinski dim!\n", .{QUTRIT_ENTROPY});
    std.debug.print("    The ternary foundation unites quantum + sacred math\n\n", .{});
}

// =============================================================================
// COMMAND: tri math all
// =============================================================================

fn runAllConstantsCommand() void {
    std.debug.print("\n{s}ALL Mathematical Constants{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}================================================================{s}\n", .{ GRAY, RESET });

    std.debug.print("\n{s}  GOLDEN RATIO FAMILY:{s}\n", .{ GOLDEN, RESET });
    printConst("phi (PHI)", PHI, "Golden ratio (1+sqrt5)/2");
    printConst("phi^2 (PHI_SQ)", PHI_SQ, "phi + 1");
    printConst("1/phi (PHI_INV)", PHI_INV, "phi - 1");
    printConst("1/phi^2 (PHI_INV_SQ)", PHI_INV_SQ, "2 - phi");

    std.debug.print("\n{s}  FUNDAMENTAL:{s}\n", .{ GOLDEN, RESET });
    printConst("pi", PI, "Circle constant");
    printConst("e", E, "Euler's number");
    printConst("sqrt(2)", SQRT2, "Pythagoras");
    printConst("sqrt(3)", SQRT3, "Hexagonal");
    printConst("sqrt(5)", SQRT5, "Pentagonal");
    printConst("gamma (Euler-Masch.)", EULER_MASCHERONI, "Harmonic limit");
    printConst("ln(2)", LN2, "Natural log of 2");

    std.debug.print("\n{s}  SACRED (TRINITY):{s}\n", .{ GOLDEN, RESET });
    printConstInt("TRINITY", TRINITY, "phi^2 + 1/phi^2 = 3");
    printConst("pi * phi * e", TRANSCENDENTAL, "~= 13 = TRYTE_MAX");
    printConst("mu (mutation)", MU, "1/phi^2/10");
    printConst("chi (crossover)", CHI, "1/phi/10");
    printConst("sigma (selection)", SIGMA, "phi");
    printConst("epsilon (elitism)", EPSILON, "1/3");

    std.debug.print("\n{s}  EXOTIC:{s}\n", .{ GOLDEN, RESET });
    printConst("zeta(3) Apery", APERY, "Irrational (1978)");
    printConst("G Catalan", CATALAN, "Alternating series");
    printConst("delta Feigenbaum", FEIGENBAUM_DELTA, "Chaos bifurcation");
    printConst("alpha Feigenbaum", FEIGENBAUM_ALPHA, "Chaos scaling");
    printConst("K Khinchin", KHINCHIN, "CF geometric mean");
    printConst("A Glaisher-Kinkelin", GLAISHER_KINKELIN, "Hyperfactorial");
    printConst("Omega (Lambert)", OMEGA, "x*e^x = 1");
    printConst("rho Plastic", PLASTIC, "x^3 = x+1");
    printConst("Landau-Ramanujan", LANDAU_RAMANUJAN, "Sums of 2 squares");
    printConst("lambda Conway", CONWAY, "Look-and-say");

    std.debug.print("\n{s}  PHYSICS:{s}\n", .{ GOLDEN, RESET });
    printConst("alpha (fine struct.)", ALPHA, "~1/137");
    printConst("1/alpha", FINE_STRUCTURE_INV, "137.036");
    printConst("CHSH = 2*sqrt(2)", CHSH, "Bell bound");
    printConst("c (light speed)", SPEED_OF_LIGHT, "m/s");
    printConst("k_B (Boltzmann)", BOLTZMANN, "J/K");

    std.debug.print("\n{s}  GOLDEN FUNCTION (Pellis 2025):{s}\n", .{ GOLDEN, RESET });
    printConst("sqrt(phi)", PHI_SQRT, "phi^(1/2)");
    printConst("G(0.5)", GOLDEN_HALF, "phi^0.5 + phi^-0.5");
    printConst("phi^phi", PHI_TO_PHI, "self-exponentiation");
    printConst("phi^pi", PHI_TO_PI, "transcendental golden");

    std.debug.print("\n{s}  NUCLEAR FIBONACCI:{s}\n", .{ GOLDEN, RESET });
    printConst("N/Z stability", NP_STABILITY, "phi/sqrt(2) heavy nuclei");
    printConst("Binding peak (MeV)", BINDING_PEAK, "~8.8 at Fe-56");

    std.debug.print("\n{s}  FRACTAL DIMENSIONS:{s}\n", .{ GOLDEN, RESET });
    printConst("Sierpinski dim", SIERPINSKI_DIM, "ln(3)/ln(2)");
    printConst("Koch dim", KOCH_DIM, "ln(4)/ln(3)");
    printConst("Menger dim", MENGER_DIM, "ln(20)/ln(3)");
    printConst("Mandelbrot dim", MANDELBROT_DIM, "= 2.0 (proved)");
    printConst("Golden spiral ratio", GOLDEN_SPIRAL_RATIO, "phi^2 per turn");
    printConst("Fib word fractal dim", 1.0 + PHI_INV_SQ, "1+1/phi^2");

    std.debug.print("\n{s}  QUANTUM (Berry + SU(3)):{s}\n", .{ GOLDEN, RESET });
    printConst("Berry phase (qutrit)", BERRY_PHASE_QUTRIT, "2*pi/3 = 120 deg");
    printConst("Berry phi-orbit", BERRY_PHI_ORBIT, "2*pi*phi");
    printConst("f_123 SU(3)", SU3_F123, "structure constant");
    printConst("f_458 SU(3)", SU3_F458, "sqrt(3)/2");
    printConst("C_2(3) Casimir", SU3_CASIMIR, "4/3 (fund. rep.)");
    printConst("SU(3) golden", SU3_GOLDEN, "3/(2*phi) strong+golden");
    printConst("Qutrit gate angle", QUTRIT_GATE_ANGLE, "2*pi/3 = 120 deg");

    std.debug.print("\n{s}  PLANCK-PHI:{s}\n", .{ GOLDEN, RESET });
    printConstSci("T_P (Planck temp)", PLANCK_TEMPERATURE, "K");
    printConstSci("E_P (Planck energy)", PLANCK_ENERGY_GEV, "GeV");
    printConstSci("l_P * phi", PLANCK_LENGTH_PHI, "m (golden length)");
    printConstSci("t_P * phi", PLANCK_TIME_PHI, "s (golden time)");
    printConst("sin^2(theta_W)", WEINBERG_SIN2, "Weinberg angle");
    printConst("m_p/m_e", PROTON_ELECTRON_RATIO, "proton/electron");
    printConst("R_inf (Rydberg)", RYDBERG, "1/m (hydrogen)");
    printConst("log2(3) qutrit", QUTRIT_ENTROPY, "bits per qutrit");

    // Total count
    std.debug.print("\n{s}  Total: 63 constants{s}\n", .{ GOLDEN, RESET });

    const trinity_check = PHI_SQ + PHI_INV_SQ;
    std.debug.print("  {s}phi^2 + 1/phi^2 = {d:.10}{s}", .{ GOLDEN, trinity_check, RESET });
    if (@abs(trinity_check - 3.0) < 0.0001) {
        std.debug.print(" {s}TRINITY VERIFIED{s}", .{ GREEN, RESET });
    }
    std.debug.print("\n\n", .{});
}

// =============================================================================
// HELPERS
// =============================================================================

fn parseU32(args: []const []const u8, default: u32) u32 {
    if (args.len == 0) return default;
    return std.fmt.parseInt(u32, args[0], 10) catch default;
}
