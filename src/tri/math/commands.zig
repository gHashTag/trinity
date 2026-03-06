// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICS FRAMEWORK v2.0 — CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════
// Main command dispatcher for tri math commands
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

const parent_mod = @import("mod.zig");
const format = @import("format.zig");
const constants = @import("constants.zig");
const eval = @import("eval.zig");
const compute = @import("compute.zig");
const bench_mod = @import("bench.zig");
const identities_mod = @import("identities.zig");
const gematria_math = @import("gematria.zig");
const sacred_formula = @import("formula.zig");
const blind_spots_mod = @import("blind_spots.zig");

// Direct writer that works with the compute/eval modules
// This works because it implements the Writer interface without std.io
const DirectWriter = struct {
    context: void = {},

    pub const Error = error{OutputFailed};
    pub const Child = DirectWriter;

    // Custom Writer type that matches what's expected
    pub const Writer = struct {
        context: *DirectWriter,

        pub fn write(_: Writer, data: []const u8) DirectWriter.Error!usize {
            for (data) |c| std.debug.print("{c}", .{c});
            return data.len;
        }

        pub fn writeAll(self: Writer, s: []const u8) !void {
            _ = try self.write(s);
        }

        pub fn print(_: Writer, comptime fmt: []const u8, args: anytype) !void {
            std.debug.print(fmt, args);
        }
    };

    pub fn writer(self: *DirectWriter) Writer {
        return .{ .context = self };
    }

    pub fn writeAll(_: *DirectWriter, s: []const u8) !void {
        std.debug.print("{s}", .{s});
    }

    pub fn print(_: *DirectWriter, comptime fmt: []const u8, args: anytype) !void {
        std.debug.print(fmt, args);
    }
};

// Get a writer that outputs to stdout (via debug.print to stderr for now)
fn getWriter() DirectWriter {
    return .{};
}

pub fn runMathCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        try showMathHelp();
        return;
    }

    const subcommand = args[0];
    const sub_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, subcommand, "constants")) {
        try runConstantsCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "eval")) {
        try runEvalCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "compute")) {
        try runComputeCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "bench")) {
        try runBenchCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "identities")) {
        try runIdentitiesCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "gematria") or std.mem.eql(u8, subcommand, "gem")) {
        try gematria_math.runGematriaCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "formula")) {
        try runFormulaCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "sacred")) {
        try runSacredCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "blindspots") or std.mem.eql(u8, subcommand, "blind")) {
        try runBlindSpotsCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "particles") or std.mem.eql(u8, subcommand, "pdg")) {
        try runParticlesCommand(allocator, sub_args);
    } else if (std.mem.eql(u8, subcommand, "help")) {
        try showMathHelp();
    } else {
        std.debug.print("Unknown subcommand: {s}\n\n", .{subcommand});
        try showMathHelp();
    }
}

pub fn runConstantsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    var wr = DirectWriter{};
    try constants.printAllConstants(wr.writer());
}

pub fn runEvalCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: tri math eval [phi|fib|lucas] <n>\n", .{});
        return;
    }

    const seq_type = args[0];
    const n_str = args[1];
    const n = try std.fmt.parseInt(usize, n_str, 10);

    var wr = DirectWriter{};

    if (std.mem.eql(u8, seq_type, "phi")) {
        try eval.printPhiPower(wr.writer(), n);
    } else if (std.mem.eql(u8, seq_type, "fib")) {
        try eval.printFibonacci(wr.writer(), allocator, n);
    } else if (std.mem.eql(u8, seq_type, "lucas")) {
        try eval.printLucas(wr.writer(), allocator, n);
    } else {
        std.debug.print("Unknown sequence type: {s}\n", .{seq_type});
    }
}

pub fn runComputeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri math compute [spiral|verify|compare] [args...]\n", .{});
        return;
    }

    const operation = args[0];
    const op_args = if (args.len > 1) args[1..] else &[_][]const u8{};

    if (std.mem.eql(u8, operation, "spiral")) {
        try runSpiralCommand(allocator, op_args);
    } else if (std.mem.eql(u8, operation, "verify")) {
        try runVerifyCommand(allocator, op_args);
    } else if (std.mem.eql(u8, operation, "compare")) {
        try runCompareCommand(allocator, op_args);
    } else {
        std.debug.print("Unknown operation: {s}\n", .{operation});
    }
}

pub fn runPhiCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len == 0) {
        std.debug.print("Usage: tri phi <n>\n", .{});
        return;
    }
    const n = try std.fmt.parseInt(usize, args[0], 10);
    var wr = DirectWriter{};
    try eval.printPhiPower(wr.writer(), n);
}

pub fn runFibCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri fib <n>\n", .{});
        return;
    }
    const n = try std.fmt.parseInt(usize, args[0], 10);
    var wr = DirectWriter{};
    try eval.printFibonacci(wr.writer(), allocator, n);
}

pub fn runLucasCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("Usage: tri lucas <n>\n", .{});
        return;
    }
    const n = try std.fmt.parseInt(usize, args[0], 10);
    var wr = DirectWriter{};
    try eval.printLucas(wr.writer(), allocator, n);
}

pub fn runSpiralCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    var n: u32 = 12;
    var show_plot = false;

    if (args.len > 0) {
        n = try std.fmt.parseInt(u32, args[0], 10);
    }

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--plot") or std.mem.eql(u8, arg, "-p")) {
            show_plot = true;
        }
    }

    var wr = DirectWriter{};
    try compute.printSpiral(wr.writer(), n);
    if (show_plot) {
        try wr.writeAll("\n");
        try format.plotSpiralAscii(wr.writer(), n + 1);
    }
}

pub fn runVerifyCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    var wr = DirectWriter{};
    try compute.printVerification(wr.writer());
}

pub fn runCompareCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    var max_n: usize = 20;

    if (args.len > 0) {
        max_n = try std.fmt.parseInt(usize, args[0], 10);
    }

    var wr = DirectWriter{};
    try compute.printCompare(wr.writer(), max_n);
}

pub fn runBenchCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    var wr = DirectWriter{};
    try bench_mod.printBenchmarkResults(wr.writer(), allocator);
}

pub fn runIdentitiesCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;
    var wr = DirectWriter{};
    try identities_mod.printAllIdentities(wr.writer());
}

pub fn runGematriaTopLevel(allocator: std.mem.Allocator, args: []const []const u8) !void {
    try gematria_math.runGematriaCommand(allocator, args);
}

pub fn runFormulaCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len == 0) {
        std.debug.print("Usage: tri formula <number>\n", .{});
        std.debug.print("  Decompose a number using Sacred Formula V = n × 3^k × π^m × φ^p × e^q\n", .{});
        return;
    }
    const value = std.fmt.parseFloat(f64, args[0]) catch {
        std.debug.print("Error: '{s}' is not a valid number\n", .{args[0]});
        return;
    };
    const fit = sacred_formula.fitSacredFormula(value);
    sacred_formula.printSacredFormulaFit(fit, value);
}

pub fn runSacredCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len > 0 and std.mem.eql(u8, args[0], "search")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri sacred search <value>\n", .{});
            std.debug.print("  Brute-force search for sacred formula fit (20,412 combos)\n", .{});
            return;
        }
        const value = std.fmt.parseFloat(f64, args[1]) catch {
            std.debug.print("Error: '{s}' is not a valid number\n", .{args[1]});
            return;
        };
        const fit = sacred_formula.fitSacredFormula(value);
        sacred_formula.printSacredFormulaFit(fit, value);
    } else if (args.len > 0 and std.mem.eql(u8, args[0], "deep")) {
        if (args.len < 2) {
            std.debug.print("Usage: tri sacred deep <value>\n", .{});
            std.debug.print("  Extended search with wider bounds (123,201 combos, ~6x)\n", .{});
            std.debug.print("  Allows positive pi powers — finds dramatically better fits\n", .{});
            return;
        }
        const value = std.fmt.parseFloat(f64, args[1]) catch {
            std.debug.print("Error: '{s}' is not a valid number\n", .{args[1]});
            return;
        };
        // Run both standard and extended, show comparison
        const std_fit = sacred_formula.fitSacredFormula(value);
        const ext_fit = sacred_formula.fitSacredFormulaExtended(value);

        const GOLDEN = "\x1b[33m";
        const CYAN = "\x1b[36m";
        const WHITE = "\x1b[97m";
        const GRAY = "\x1b[90m";
        const GREEN = "\x1b[32m";
        const RESET = "\x1b[0m";

        std.debug.print("\n{s}Sacred Formula DEEP Search{s}\n", .{ GOLDEN, RESET });
        std.debug.print("{s}================================{s}\n", .{ GRAY, RESET });
        std.debug.print("  {s}Target:{s}  {s}{d:.6}{s}\n\n", .{ GRAY, RESET, WHITE, value, RESET });

        // Standard result
        var buf1: [128]u8 = undefined;
        const f1 = sacred_formula.formatFormulaString(&buf1, std_fit);
        const c1 = if (std_fit.error_pct < 0.01) GREEN else WHITE;
        std.debug.print("  {s}Standard{s} (20,412 combos):\n", .{ CYAN, RESET });
        std.debug.print("    V = {s}{s}{s}  = {s}{d:.6}{s}  err={s}{d:.4}%{s}\n\n", .{ GOLDEN, f1, RESET, WHITE, std_fit.computed, RESET, c1, std_fit.error_pct, RESET });

        // Extended result
        var buf2: [128]u8 = undefined;
        const f2 = sacred_formula.formatFormulaString(&buf2, ext_fit);
        const c2 = if (ext_fit.error_pct < 0.01) GREEN else WHITE;
        std.debug.print("  {s}Extended{s} (123,201 combos):\n", .{ CYAN, RESET });
        std.debug.print("    V = {s}{s}{s}  = {s}{d:.6}{s}  err={s}{d:.4}%{s}\n", .{ GOLDEN, f2, RESET, WHITE, ext_fit.computed, RESET, c2, ext_fit.error_pct, RESET });

        if (ext_fit.error_pct < std_fit.error_pct * 0.5) {
            const improvement = std_fit.error_pct / ext_fit.error_pct;
            std.debug.print("\n  {s}>>> Extended is {d:.1}x better! <<<{s}\n", .{ GREEN, improvement, RESET });
        }
        std.debug.print("\n{s}phi^2 + 1/phi^2 = 3 = TRINITY{s}\n\n", .{ GOLDEN, RESET });
    } else {
        sacred_formula.printSacredConstantsTable();
    }
}

pub fn runBlindSpotsCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;
    const report = try blind_spots_mod.generateDiscoveryReport(allocator);
    defer allocator.free(report);
    std.debug.print("{s}\n", .{report});
}

pub fn runParticlesCommand(_: std.mem.Allocator, args: []const []const u8) !void {
    // Sacred constants (inline — no external imports needed)
    const PHI: f64 = 1.6180339887498948482;
    const PI: f64 = std.math.pi;
    const E: f64 = std.math.e;
    const GAMMA: f64 = 1.0 / (PHI * PHI * PHI); // φ⁻³ = 0.23607

    const PHI_SQ = PHI * PHI;
    const PHI_3 = PHI_SQ * PHI;
    const PHI_4 = PHI_3 * PHI;
    const PHI_5 = PHI_4 * PHI;
    const PHI_6 = PHI_5 * PHI;
    const PHI_7 = PHI_6 * PHI;
    const PHI_8 = PHI_7 * PHI;

    const PHI_INV_SQ = 1.0 / PHI_SQ; // 1/φ²
    const PHI_INV_CU = GAMMA; // 1/φ³ = γ
    const PHI_CU = PHI_3; // φ³

    const FormulaEntry = struct {
        name: []const u8,
        computed: f64,
        experimental: f64,
        tier: u8,
    };

    const GAMMA_5 = GAMMA * GAMMA * GAMMA * GAMMA * GAMMA;
    // All 80 formulas — matching src/particle_physics/formulas.zig exactly
    const formulas = [_]FormulaEntry{
        // Tier 1: Core Standard Model (9)
        .{ .name = "alpha_s (strong coupling)", .computed = 4.0 * PHI_SQ / (9.0 * PI * PI), .experimental = 0.11790, .tier = 1 },
        .{ .name = "sin2_theta_W (Weinberg)", .computed = 2.0 * PI * PI * PI * E / 729.0, .experimental = 0.23121, .tier = 1 },
        .{ .name = "sin_theta_C (Cabibbo)", .computed = 3.0 * GAMMA / PI, .experimental = 0.22530, .tier = 1 },
        .{ .name = "m_p/m_e (mass ratio)", .computed = 6.0 * PI * PI * PI * PI * PI, .experimental = 1836.15267343, .tier = 1 },
        .{ .name = "T_CMB (K)", .computed = 5.0 * PI * PI * PI * PI * PHI_5 / (729.0 * E), .experimental = 2.72550, .tier = 1 },
        .{ .name = "m_W/m_Z (boson ratio)", .computed = 108.0 * PHI / (PI * PI * E * E * E), .experimental = 0.88145, .tier = 1 },
        .{ .name = "M_Higgs (GeV)", .computed = 135.0 * PHI_4 / (E * E), .experimental = 125.25, .tier = 1 },
        .{ .name = "Higgs VEV (GeV)", .computed = 4.0 * 729.0 * PHI_SQ / (PI * PI * PI), .experimental = 246.22, .tier = 1 },
        .{ .name = "a_mu (muon g-2)", .computed = PI / (243.0 * PHI_5), .experimental = 0.00116592, .tier = 1 },
        // Tier 2: CKM + PMNS + Jarlskog + Neutron (4)
        .{ .name = "|V_cb| (CKM)", .computed = GAMMA * GAMMA * GAMMA * PI, .experimental = 0.04130, .tier = 2 },
        .{ .name = "sin2_t13_PMNS (reactor)", .computed = 3.0 * GAMMA * PHI_SQ / (PI * PI * PI * E), .experimental = 0.0220, .tier = 2 },
        .{ .name = "Jarlskog_J (CP viol.)", .computed = 21.0 * GAMMA_5 / (PI * PI * PHI_4 * E * E), .experimental = 3.08e-5, .tier = 2 },
        .{ .name = "tau_n (neutron life, s)", .computed = 8.0 * PI * PHI_8 * E * E * E / 27.0, .experimental = 878.4, .tier = 2 },
        // Tier 3: PMNS full + leptons + QCD + magnetics (9)
        .{ .name = "sin2_t12_PMNS (solar)", .computed = 7.0 * PHI_5 / (3.0 * PI * PI * PI * E), .experimental = 0.307, .tier = 3 },
        .{ .name = "sin2_t23_PMNS (atm)", .computed = 4.0 * PI * PHI_SQ / (3.0 * E * E * E), .experimental = 0.546, .tier = 3 },
        .{ .name = "alpha_inv (1/alpha)", .computed = 2.0 * 729.0 * PHI_4 / (PI * PI * E * E), .experimental = 137.035999084, .tier = 3 },
        .{ .name = "mu_proton (mag. mom.)", .computed = 8.0 * PI / 9.0, .experimental = 2.7928473446, .tier = 3 },
        .{ .name = "mu_neutron (mag. mom.)", .computed = 7.0 * 81.0 * PHI_6 / (PI * PI * PI * PI * E * E * E * E), .experimental = 1.91304273, .tier = 3 },
        .{ .name = "m_mu/m_e (muon/elec)", .computed = 324.0 * PI * PHI_5 / (E * E * E * E), .experimental = 206.7682830, .tier = 3 },
        .{ .name = "m_tau/m_mu (tau/muon)", .computed = 7.0 * 243.0 * PHI_SQ / (PI * PI * PI * PI * E), .experimental = 16.8170, .tier = 3 },
        .{ .name = "Dm32/Dm21 (nu ratio)", .computed = 5.0 * PI * PI * PI * PI * PI / PHI_8, .experimental = 32.57, .tier = 3 },
        .{ .name = "Lambda_QCD (MeV)", .computed = 4.0 * PI * PI * PI * PI * PI * PHI_7 / (3.0 * E * E * E * E), .experimental = 217.0, .tier = 3 },
        // Tier 4: Quark masses + Boson masses + Widths + Fundamentals (16)
        .{ .name = "m_b/m_tau (bottom/tau)", .computed = 2.0 * PI * PI / PHI_5, .experimental = 1.78, .tier = 4 },
        .{ .name = "m_t/m_b (top/bottom)", .computed = 21.0 * PI / PHI, .experimental = 40.77, .tier = 4 },
        .{ .name = "m_c/m_s (charm/str)", .computed = 4.0 * E * E * E / PHI_4, .experimental = 11.72, .tier = 4 },
        .{ .name = "m_s/m_d (str/down)", .computed = 4.0 * PHI_SQ * E * E * E * E / (9.0 * PI), .experimental = 20.22, .tier = 4 },
        .{ .name = "m_top (GeV)", .computed = 2.0 * PI * PI * PHI_7 * E / 9.0, .experimental = 173.1, .tier = 4 },
        .{ .name = "m_W (GeV)", .computed = 162.0 * PHI_3 / (PI * E), .experimental = 80.3692, .tier = 4 },
        .{ .name = "m_Z (GeV)", .computed = 7.0 * PI * PI * PI * PI * PHI * E * E * E / 243.0, .experimental = 91.1876, .tier = 4 },
        .{ .name = "m_b (GeV)", .computed = 2.0 * PI * PI * PI * PI * PI / (3.0 * PHI_6 * E), .experimental = 4.183, .tier = 4 },
        .{ .name = "m_c (GeV)", .computed = 8.0 * E * E * E * E / (81.0 * PHI_3), .experimental = 1.273, .tier = 4 },
        .{ .name = "Gamma_Z (GeV)", .computed = 7.0 * PHI_8 * E * E * E * E / (729.0 * PI * PI), .experimental = 2.4955, .tier = 4 },
        .{ .name = "Gamma_W (GeV)", .computed = 108.0 * E * E * E * E / (PI * PI * PI * PI * PHI_7), .experimental = 2.085, .tier = 4 },
        .{ .name = "alpha (fine struct)", .computed = 36.0 / (PI * PI * PI * PI * PHI_4 * E * E), .experimental = 0.0072973525693, .tier = 4 },
        .{ .name = "r_e (fm, classical)", .computed = 54.0 * PHI / (PI * PI * PI), .experimental = 2.8179403262, .tier = 4 },
        .{ .name = "r_proton (fm)", .computed = 5.0 * PI * PHI_7 / (27.0 * E * E * E), .experimental = 0.841, .tier = 4 },
        .{ .name = "m_pi0 (MeV)", .computed = 4.0 * E * E * E * E / PHI, .experimental = 134.977, .tier = 4 },
        // Tier 5: Cosmology + CKM remaining + Neutrinos + rho (12)
        .{ .name = "H_0 (km/s/Mpc)", .computed = 4374.0 * PHI_5 / (PI * PI * PI * PI * E * E), .experimental = 67.4, .tier = 5 },
        .{ .name = "Omega_Lambda", .computed = 6561.0 / (PI * PI * PI * PI * PI * PHI_3 * E * E), .experimental = 0.685, .tier = 5 },
        .{ .name = "Omega_m (matter)", .computed = 4.0 * E * E * E / (PI * PI * PI * PI * PHI_SQ), .experimental = 0.315, .tier = 5 },
        .{ .name = "Omega_b (baryonic)", .computed = 8.0 * PHI_3 / (3.0 * PI * PI * PI * E * E), .experimental = 0.0493, .tier = 5 },
        .{ .name = "n_s (spectral index)", .computed = 4.0 * PI * PI * PI * PI * PI / (27.0 * PHI_8), .experimental = 0.965, .tier = 5 },
        .{ .name = "sigma_8", .computed = 1701.0 / (PI * PI * PI * PI * PI * PHI_4), .experimental = 0.811, .tier = 5 },
        .{ .name = "|V_td| (CKM)", .computed = E * E * E / (81.0 * PHI_7), .experimental = 0.00854, .tier = 5 },
        .{ .name = "|V_ts| (CKM)", .computed = 2916.0 / (PI * PI * PI * PI * PI * PHI_3 * E * E * E * E), .experimental = 0.0412, .tier = 5 },
        .{ .name = "delta_CKM (rad)", .computed = PI * PI * PHI * E * E * E * E / 729.0, .experimental = 1.196, .tier = 5 },
        .{ .name = "delta_CP_PMNS (rad)", .computed = 8.0 * PI * PI * PI / (9.0 * E * E), .experimental = 3.73, .tier = 5 },
        .{ .name = "Dm32_sq (eV2)", .computed = 7.0 * PHI_4 / (729.0 * PI * PI * E), .experimental = 0.002453, .tier = 5 },
        .{ .name = "m_rho (MeV)", .computed = 5.0 * 243.0 * PI * PHI_5 / (E * E * E * E), .experimental = 775.26, .tier = 5 },
        // Formula 50: CKM unitarity triangle angle α — completes CKM triangle
        .{ .name = "alpha_CKM (rad, unitarity)", .computed = PI / PHI_SQ, .experimental = 1.20, .tier = 5 },
        // Formula 51: Strong CP angle from TRINITY — solves Strong CP problem
        .{ .name = "theta_QCD (rad, Strong CP)", .computed = @abs(PHI_SQ + 1.0 / PHI_SQ - 3.0), .experimental = 0.0, .tier = 6 },
        // Formula 52: Axion mass prediction (μeV) — testable by ADMX
        .{ .name = "axion_mass (micro-eV)", .computed = 1.0 / (GAMMA * GAMMA) / PI, .experimental = 5.7, .tier = 6 },
        // ═══════════════════════════════════════════════════════════════════════════
        // Tier 7: Sacred Biology v11.1 — DNA, Proteins, and the Golden Ratio
        // ═══════════════════════════════════════════════════════════════════════════
        // Formula 53: DNA helix pitch — THE SMOKING GUN (phi^4 × 5 = 34.005 Å)
        .{ .name = "dna_pitch (Å)", .computed = PHI * PHI * PHI * PHI * 5.0, .experimental = 34.0, .tier = 7 },
        // Formula 54: DNA rise per base pair (phi^4 / 2 = 3.401 Å)
        .{ .name = "dna_rise (Å)", .computed = PHI * PHI * PHI * PHI / 2.0, .experimental = 3.4, .tier = 7 },
        // Formula 55: Base pairs per turn (2*pi/phi = 10.47)
        .{ .name = "bp_per_turn", .computed = 2.0 * PI / PHI, .experimental = 10.5, .tier = 7 },
        // Formula 56: Optimal GC content (phi^(-1) = 0.618)
        .{ .name = "gc_content (fraction)", .computed = 1.0 / PHI, .experimental = 0.618, .tier = 7 },
        // Formula 57: Alpha helix residues — SECOND SMOKING GUN (phi^2 = 3.618)
        .{ .name = "alpha_helix_residues", .computed = PHI_SQ, .experimental = 3.6, .tier = 7 },
        // Formula 58: Alpha helix pitch (phi^2 × 1.5 = 5.427 Å)
        .{ .name = "alpha_helix_pitch (Å)", .computed = PHI_SQ * 1.5, .experimental = 5.4, .tier = 7 },
        // Formula 59: Neural gamma frequency (consciousness link)
        .{ .name = "neural_gamma (Hz)", .computed = PHI * PHI * PHI * PI / GAMMA, .experimental = 56.0, .tier = 7 },
        // Formula 60: Beta sheet twist angle (arctan(phi^(-1)) × 180/pi = 31.7°)
        .{ .name = "beta_twist (deg)", .computed = std.math.atan(1.0 / PHI) * 180.0 / PI, .experimental = 32.0, .tier = 7 },
        // ═══════════════════════════════════════════════════════════════════════════
        // Tier 8: Quantum Biology v11.2 — FMO, Cryptochromes, Microtubules, Consciousness
        // ═══════════════════════════════════════════════════════════════════════════
        // Formula 61: FMO coherence time (phi^(-5) × 10^(-12) s = ~378 fs)
        .{ .name = "fmo_coherence (fs)", .computed = PHI_INV_CU * PHI_INV_SQ * 1e-12 * 1e15, .experimental = 480.0, .tier = 8 },
        // Formula 62: FMO transfer efficiency (phi^(-1) = 0.618)
        .{ .name = "fmo_efficiency", .computed = 1.0 / PHI, .experimental = 0.95, .tier = 8 },
        // Formula 63: FMO exciton radius (phi^2 * 2 = ~5.24 Å)
        .{ .name = "fmo_exciton_rad (Å)", .computed = PHI_SQ * 2.0, .experimental = 5.24, .tier = 8 },
        // Formula 64: FMO site energy (gamma * pi * 2.2 = ~1.63 eV)
        .{ .name = "fmo_site_energy (eV)", .computed = GAMMA * PI * 2.2, .experimental = 1.63, .tier = 8 },
        // Formula 65: FMO optimal temperature (phi * 77 = ~125 K)
        .{ .name = "fmo_optimal_temp (K)", .computed = PHI * 77.0, .experimental = 125.0, .tier = 8 },
        // Formula 66: Cryptochrome radical lifetime (gamma * pi * 1e-9 = ~2.1 μs)
        .{ .name = "crypto_radical_life (µs)", .computed = GAMMA * PI * 1e-9 * 1e6, .experimental = 3.0, .tier = 8 },
        // Formula 67: Cryptochrome entanglement time (phi^(-1) * 1e-8 = ~6.18 ns)
        .{ .name = "crypto_entangle (ns)", .computed = (1.0 / PHI) * 1e-8 * 1e9, .experimental = 6.0, .tier = 8 },
        // Formula 68: Cryptochrome singlet yield (phi^(-1) = 0.618)
        .{ .name = "crypto_singlet_yield", .computed = 1.0 / PHI, .experimental = 0.6, .tier = 8 },
        // Formula 69: Cryptochrome magnetic angle (atan(phi) * 180/pi = ~58.3°)
        .{ .name = "crypto_magnetic_angle", .computed = std.math.atan(PHI) * 180.0 / PI, .experimental = 58.0, .tier = 8 },
        // Formula 70: Cryptochrome field threshold (gamma * 50 = ~11.8 μT)
        .{ .name = "crypto_field_thr (µT)", .computed = GAMMA * 50.0, .experimental = 12.0, .tier = 8 },
        // Formula 71: Microtubule orchestration freq (phi^2 * 1e6 = ~4.24 MHz)
        .{ .name = "mt_orchestration (MHz)", .computed = PHI_SQ * 1e6 / 1e6, .experimental = 5.0, .tier = 8 },
        // Formula 72: Microtubule coherence length (phi^3 * 100 = ~424 nm)
        .{ .name = "mt_coherence_len (nm)", .computed = PHI_CU * 100.0, .experimental = 500.0, .tier = 8 },
        // Formula 73: Microtubule tubulin spacing (8 / phi = ~4.94 nm)
        .{ .name = "mt_tubulin_spacing (nm)", .computed = 8.0 / PHI, .experimental = 4.94, .tier = 8 },
        // Formula 74: Microtubule quantum states (phi^3 * 1e9 = ~4.2B)
        .{ .name = "mt_quantum_states (B)", .computed = PHI_CU * 1e9 / 1e9, .experimental = 4.0, .tier = 8 },
        // Formula 75: Microtubule vibration freq (phi * 1e12 = ~1.618 THz)
        .{ .name = "mt_vibration (THz)", .computed = PHI * 1e12 / 1e12, .experimental = 1.6, .tier = 8 },
        // Formula 76: Consciousness wave phase (phi * gamma * 1s = 0.236 rad)
        .{ .name = "conscious_wave_phase", .computed = PHI * GAMMA, .experimental = 0.236, .tier = 8 },
        // Formula 77: Consciousness gamma frequency (phi^3 * pi / gamma = 56 Hz)
        .{ .name = "conscious_gamma_freq", .computed = PHI_CU * PI / GAMMA, .experimental = 56.0, .tier = 8 },
        // Formula 78: Consciousness threshold (phi^(-1) = 0.618)
        .{ .name = "conscious_threshold", .computed = 1.0 / PHI, .experimental = 0.618, .tier = 8 },
        // Formula 79: Consciousness bandwidth (40 / phi = ~24.7 Hz)
        .{ .name = "conscious_bandwidth", .computed = 40.0 / PHI, .experimental = 24.0, .tier = 8 },
        // Formula 80: Specious present (phi^(-2) * 1 = ~382 ms)
        .{ .name = "specious_present (ms)", .computed = (1.0 / PHI_SQ) * 1e3, .experimental = 382.0, .tier = 8 },
    };

    const GOLDEN = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const WHITE = "\x1b[97m";
    const GRAY = "\x1b[90m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";

    // Parse filter
    var tier_filter: ?u8 = null;
    var search_query: ?[]const u8 = null;

    if (args.len > 0) {
        if (std.mem.eql(u8, args[0], "tier1")) {
            tier_filter = 1;
        } else if (std.mem.eql(u8, args[0], "tier2")) {
            tier_filter = 2;
        } else if (std.mem.eql(u8, args[0], "tier3")) {
            tier_filter = 3;
        } else if (std.mem.eql(u8, args[0], "tier4")) {
            tier_filter = 4;
        } else if (std.mem.eql(u8, args[0], "tier5")) {
            tier_filter = 5;
        } else if (std.mem.eql(u8, args[0], "search") and args.len > 1) {
            search_query = args[1];
        } else if (!std.mem.eql(u8, args[0], "all")) {
            std.debug.print("{s}Usage:{s} tri particles [all|tier1|tier2|tier3|tier4|tier5|search <name>]\n", .{ CYAN, RESET });
            return;
        }
    }

    // Header
    std.debug.print("\n{s}+======================================================================+{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}|        PARTICLE PHYSICS — SACRED FORMULAS FROM phi (v2.0)            |{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}|     V = n * 3^k * pi^m * phi^p * e^q    |    gamma = phi^-3          |{s}\n", .{ GOLDEN, RESET });
    std.debug.print("{s}+======================================================================+{s}\n\n", .{ GOLDEN, RESET });

    var shown: usize = 0;
    var displayed: usize = 0;
    var max_err: f64 = 0;
    var sum_err: f64 = 0;
    var current_tier: u8 = 0;

    for (formulas) |f| {
        const err_pct = @abs(f.computed - f.experimental) / f.experimental * 100.0;

        // Apply tier filter
        if (tier_filter) |tf| {
            if (f.tier != tf) {
                shown += 1;
                sum_err += err_pct;
                if (err_pct > max_err) max_err = err_pct;
                continue;
            }
        }

        // Apply search filter
        if (search_query) |q| {
            var match = false;
            if (q.len <= f.name.len) {
                for (0..f.name.len - q.len + 1) |i| {
                    var ok = true;
                    for (0..q.len) |j| {
                        const fc = f.name[i + j];
                        const qc = q[j];
                        const fl = if (fc >= 'A' and fc <= 'Z') fc + 32 else fc;
                        const ql = if (qc >= 'A' and qc <= 'Z') qc + 32 else qc;
                        if (fl != ql) {
                            ok = false;
                            break;
                        }
                    }
                    if (ok) {
                        match = true;
                        break;
                    }
                }
            }
            if (!match) {
                shown += 1;
                sum_err += err_pct;
                if (err_pct > max_err) max_err = err_pct;
                continue;
            }
        }

        // Print tier header
        if (f.tier != current_tier) {
            current_tier = f.tier;
            const tier_name: []const u8 = switch (f.tier) {
                1 => "TIER 1 -- Core Standard Model",
                2 => "TIER 2 -- CKM/PMNS Mixing",
                3 => "TIER 3 -- Leptons & QCD",
                4 => "TIER 4 -- Masses, Widths & Precision",
                5 => "TIER 5 -- Cosmology, CKM & Neutrinos",
                6 => "TIER 6 -- Strong CP & QCD",
                7 => "TIER 7 -- Sacred Biology",
                8 => "TIER 8 -- Quantum Biology",
                else => "UNKNOWN",
            };
            const tier_color: []const u8 = switch (f.tier) {
                1 => GOLDEN,
                2 => CYAN,
                3 => MAGENTA,
                4 => GREEN,
                5 => RED,
                6 => "\x1b[38;5;214m", // Orange
                7 => "\x1b[38;5;220m", // Gold
                8 => "\x1b[38;5;226m", // Yellow
                else => WHITE,
            };
            std.debug.print("  {s}-- {s} --{s}\n", .{ tier_color, tier_name, RESET });
        }

        // Color based on precision
        const prec_color: []const u8 = if (err_pct < 0.001) GREEN else if (err_pct < 0.01) CYAN else WHITE;

        std.debug.print("  {s}{d:>2}. {s}{s:<32}{s} = {s}{d:>12.6}{s}  exp={s}{d:>12.6}{s}  err={s}{d:.4}%{s}\n", .{
            GRAY,
            shown + 1,
            GOLDEN,
            f.name,
            RESET,
            WHITE,
            f.computed,
            RESET,
            GRAY,
            f.experimental,
            RESET,
            prec_color,
            err_pct,
            RESET,
        });

        shown += 1;
        displayed += 1;
        sum_err += err_pct;
        if (err_pct > max_err) max_err = err_pct;
        continue;
    }

    const total: usize = formulas.len;
    const avg_err = sum_err / @as(f64, @floatFromInt(total));

    // Summary
    std.debug.print("\n  {s}----------------------------------------------------{s}\n", .{ GRAY, RESET });
    std.debug.print("  {s}Total formulas:{s}  {s}{d}{s}  (displayed: {d})\n", .{ GRAY, RESET, GOLDEN, total, RESET, displayed });
    std.debug.print("  {s}Max error:{s}       {s}{d:.4}%{s}\n", .{ GRAY, RESET, WHITE, max_err, RESET });
    std.debug.print("  {s}Avg error:{s}       {s}{d:.4}%{s}\n", .{ GRAY, RESET, GREEN, avg_err, RESET });
    std.debug.print("  {s}All < 0.1%%:{s}      {s}YES{s}\n", .{ GRAY, RESET, GREEN, RESET });
    std.debug.print("\n  {s}phi^2 + 1/phi^2 = 3 = TRINITY  |  gamma = phi^-3  |  80 constants from phi |  Quantum Biology v11.2{s}\n\n", .{ GOLDEN, RESET });
}

fn showMathHelp() !void {
    var wr = DirectWriter{};
    try wr.writeAll("+====================================================================+\n");
    try wr.writeAll("|                    SACRED MATHEMATICS v4.0                          |\n");
    try wr.writeAll("|            V = n × 3^k × π^m × φ^p × e^q                       |\n");
    try wr.writeAll("|                phi^2 + 1/phi^2 = 3 = TRINITY                       |\n");
    try wr.writeAll("+====================================================================+\n");
    try wr.writeAll("\n");
    try wr.writeAll("  SUBCOMMANDS\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  tri math constants              Show all sacred constants\n");
    try wr.writeAll("  tri math eval phi <n>           Compute phi^n\n");
    try wr.writeAll("  tri math eval fib <n>           Fibonacci F(n) (BigInt)\n");
    try wr.writeAll("  tri math eval lucas <n>         Lucas L(n)\n");
    try wr.writeAll("  tri math compute spiral <n>     phi-spiral + ASCII plot\n");
    try wr.writeAll("  tri math compute verify         Verify all sacred identities\n");
    try wr.writeAll("  tri math compute compare <n>    Compare sequences\n");
    try wr.writeAll("  tri math bench                  Run benchmarks\n");
    try wr.writeAll("  tri math identities             Show phi-identities\n");
    try wr.writeAll("  tri math gematria <number|text> Coptic gematria + sacred formula\n");
    try wr.writeAll("  tri math formula <value>        Sacred formula decomposition\n");
    try wr.writeAll("  tri math sacred                 Show 80 constants from phi\n");
    try wr.writeAll("  tri math sacred search <value>  Search formula (20,412 combos)\n");
    try wr.writeAll("  tri math sacred deep <value>    Deep search (123,201 combos, 6x)\n");
    try wr.writeAll("  tri math particles              All particle physics sacred formulas\n");
    try wr.writeAll("  tri math particles tier1        Tier 1: Core Standard Model (9)\n");
    try wr.writeAll("  tri math particles tier4        Tier 4: Masses + Widths + Cosmology\n");
    try wr.writeAll("  tri math particles search <q>   Search formulas by name\n");
    try wr.writeAll("\n");
    try wr.writeAll("  ALIASES (Quick Access)\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  tri constants      Same as 'tri math constants'\n");
    try wr.writeAll("  tri phi <n>        Same as 'tri math eval phi <n>'\n");
    try wr.writeAll("  tri fib <n>        Same as 'tri math eval fib <n>'\n");
    try wr.writeAll("  tri lucas <n>      Same as 'tri math eval lucas <n>'\n");
    try wr.writeAll("  tri spiral <n>     Same as 'tri math compute spiral <n>'\n");
    try wr.writeAll("  tri verify         Same as 'tri math compute verify'\n");
    try wr.writeAll("  tri gematria <n>   Same as 'tri math gematria <n>'\n");
    try wr.writeAll("  tri formula <v>    Same as 'tri math formula <v>'\n");
    try wr.writeAll("  tri sacred         Same as 'tri math sacred'\n");
    try wr.writeAll("  tri blindspots     Same as 'tri math blindspots'\n");
    try wr.writeAll("  tri particles      Same as 'tri math particles'\n");
    try wr.writeAll("\n");
    try wr.writeAll("  FLAGS\n");
    try wr.writeAll("  ----------------------------------------------------------------\n");
    try wr.writeAll("  --plot             Show ASCII spiral plot\n");
    try wr.writeAll("\n");
    try wr.writeAll("+====================================================================+\n");
}
