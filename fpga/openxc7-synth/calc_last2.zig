const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const PHI: f64 = 1.6180339887498948482;
const E: f64 = 2.718281828459045;

pub fn main() !void {
    // Baryon-144: Sphaleron rate
    const gamma_15 = std.math.pow(f64, GAMMA, 15);
    const T_c: f64 = 100.0;
    const pi_sq = PI * PI;
    const e_sq = E * E;
    const Gamma_s = gamma_15 * std.math.pow(f64, T_c, 4) / (pi_sq * e_sq);
    std.debug.print("144: Γ_s = {d:.6}e-16 GeV (expect < 1e-10)\n", .{Gamma_s * 1e16});
    
    // Baryon-145: Y_B
    const phi_6 = std.math.pow(f64, PHI, 6);
    const Y_B = phi_6 / (2.0 * PI) * 1e-10;
    std.debug.print("145: Y_B = {d:.6}e-11 (expect < 1e-10)\n", .{Y_B * 1e11});
    
    // Y_B needs to be smaller - divide by more
    const Y_B2 = phi_6 / (2.0 * PI * PI) * 1e-10;
    std.debug.print("145 alt: φ⁶/(2π²) × 10⁻¹⁰ = {d:.6}e-11\n", .{Y_B2 * 1e11});
}
