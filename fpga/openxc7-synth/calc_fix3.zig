const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const PHI: f64 = 1.6180339887498948482;

pub fn main() !void {
    // Baryon-144: Sphaleron rate with current formula
    const gamma_13 = std.math.pow(f64, GAMMA, 13);
    const T_c: f64 = 100.0;
    const pi_sq = PI * PI;
    const Gamma_s = gamma_13 * std.math.pow(f64, T_c, 4) / pi_sq;
    std.debug.print("144: Γ_s = {d:.6}e-13 GeV (expect < 1e-10)\n", .{Gamma_s * 1e13});
    
    // Baryon-145: Y_B with current formula
    const phi_6 = std.math.pow(f64, PHI, 6);
    const Y_B = phi_6 * 1e-11;
    std.debug.print("145: Y_B = {d:.6}e-11 (expect < 1e-10)\n", .{Y_B * 1e11});
    
    // Baryon-150: R_MA with current formula
    const gamma_10 = std.math.pow(f64, GAMMA, 10);
    const pi_sq2 = PI * PI;
    const R_MA = 1.0 / (gamma_10 * pi_sq2);
    std.debug.print("150: R_MA = {d:.6}e+85 (expect > 1e80)\n", .{R_MA * 1e-85});
    
    // Try different formula for R_MA
    const gamma_inv_8 = std.math.pow(f64, 1.0 / GAMMA, 8);
    const pi_4 = std.math.pow(f64, PI, 4);
    const R_MA2 = gamma_inv_8 * pi_4;
    std.debug.print("150 alt: γ⁻⁸ × π⁴ = {d:.6}e+85\n", .{R_MA2 * 1e-85});
}
