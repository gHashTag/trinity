const std = @import("std");
const plasma = @import("formulas.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut();
    const stdout = stdout_file.writer();

    const T_fusion = plasma.eVToKelvin(1000.0); // 1 keV
    const n_fusion = 1.0e20; // 10^20 m⁻³
    const T_hydrogen = 15000.0; // K
    const E_i_hydrogen = 13.6 * plasma.E_CHARGE; // J

    // Test 1: Plasma frequency
    const omega_p = plasma.plasmaFrequency(n_fusion);
    try stdout.print("Plasma Frequency (n={e}):\n", .{n_fusion});
    try stdout.print("  Computed:     {e:.6} rad/s\n", .{omega_p});
    try stdout.print("  Experimental: {e:.6} rad/s\n", .{plasma.OMEGA_P_TYPICAL_EXP});
    try stdout.print("  Error:        {d:.4}%\n\n", .{plasma.errorPercent(omega_p, plasma.OMEGA_P_TYPICAL_EXP)});

    // Test 2: Debye length
    const lambda_D = plasma.debyeLength(T_fusion, n_fusion);
    try stdout.print("Debye Length (T={d}K, n={e}):\n", .{ T_fusion, n_fusion });
    try stdout.print("  Computed:     {e:.6} m\n", .{lambda_D});
    try stdout.print("  Experimental: {e:.6} m\n", .{plasma.DEBYE_LENGTH_TYPICAL_EXP});
    try stdout.print("  Error:        {d:.4}%\n\n", .{plasma.errorPercent(lambda_D, plasma.DEBYE_LENGTH_TYPICAL_EXP)});

    // Test 3: Saha ionization
    const ionization = plasma.sahaIonization(T_hydrogen, E_i_hydrogen);
    try stdout.print("Saha Ionization (T={d}K):\n", .{T_hydrogen});
    try stdout.print("  Computed:     {e:.6}\n", .{ionization});
    try stdout.print("  Experimental: {e:.6}\n", .{plasma.IONIZATION_FRACTION_EXP});
    try stdout.print("  Error:        {d:.4}%\n\n", .{plasma.errorPercent(ionization, plasma.IONIZATION_FRACTION_EXP)});

    // Test 4: Plasma parameter
    const Gamma = plasma.plasmaParameter(T_fusion, n_fusion);
    try stdout.print("Plasma Parameter (T={d}K, n={e}):\n", .{ T_fusion, n_fusion });
    try stdout.print("  Computed:     {e:.6}\n", .{Gamma});
    try stdout.print("  Experimental: {e:.6}\n", .{plasma.PLASMA_PARAM_EXP});
    try stdout.print("  Error:        {d:.4}%\n\n", .{plasma.errorPercent(Gamma, plasma.PLASMA_PARAM_EXP)});

    // Test 5: Cyclotron frequency
    const omega_c = plasma.cyclotronFrequency(5.0);
    try stdout.print("Cyclotron Frequency (B=5T):\n", .{});
    try stdout.print("  Computed:     {e:.6} rad/s\n", .{omega_c});
    try stdout.print("  Experimental: {e:.6} rad/s\n", .{8.78e11});
    try stdout.print("  Error:        {d:.4}%\n\n", .{plasma.errorPercent(omega_c, 8.78e11)});

    // Test 6: Plasma beta
    const beta = plasma.plasmaBeta(T_fusion, n_fusion, 5.0);
    try stdout.print("Plasma Beta (T={d}K, n={e}, B=5T):\n", .{ T_fusion, n_fusion });
    try stdout.print("  Computed:     {e:.6}\n", .{beta});
    try stdout.print("  Experimental: {e:.6}\n", .{0.02});
    try stdout.print("  Error:        {d:.4}%\n\n", .{plasma.errorPercent(beta, 0.02)});

    // Print sacred corrections
    try stdout.print("\nSacred Corrections:\n", .{});
    try stdout.print("  √(3φ) = {d:.6}\n", .{plasma.SQRT_3PHI});
    try stdout.print("  γ⁻¹ = {d:.6}\n", .{plasma.GAMMA_INV});
    try stdout.print("  φ^γ = {d:.6}\n", .{std.math.pow(f64, plasma.PHI, plasma.GAMMA)});
    try stdout.print("  √(φ/3) = {d:.6}\n", .{plasma.SQRT_PHI_OVER_3});
}
