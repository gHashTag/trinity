const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const PHI: f64 = 1.6180339887498948482;
const PHI_INV_SQ: f64 = 0.38196601125010515;

pub fn main() !void {
    // Baryon-144: Sphaleron rate
    const gamma_10 = std.math.pow(f64, GAMMA, 10);
    const T_c: f64 = 100.0;
    const Gamma_s = gamma_10 * std.math.pow(f64, T_c, 4);
    std.debug.print("144: Γ_s = {d:.6}e-20 GeV (expect < 1e-10)\n", .{Gamma_s * 1e20});
    
    // Baryon-145: Y_B
    const phi_6 = std.math.pow(f64, PHI, 6);
    const Y_B = phi_6 * 1e-9;
    std.debug.print("145: Y_B = {d:.6}e-10 (expect < 1e-10)\n", .{Y_B * 1e10});
    
    // Baryon-146: n/p
    const n_over_p = PHI_INV_SQ * GAMMA;
    std.debug.print("146: n/p = {d:.4} (expect 0.12-0.20)\n", .{n_over_p});
    
    // Baryon-149: R_Li
    const R_Li = (1.0 / (GAMMA * GAMMA)) * 1e-10;
    std.debug.print("149: R_Li = {d:.6}e-9 (expect < 1e-9)\n", .{R_Li * 1e9});
    
    // Baryon-150: R_MA
    const gamma_inv_10 = std.math.pow(f64, 1.0 / GAMMA, 10);
    const pi_15 = std.math.pow(f64, PI, 15);
    const R_MA = gamma_inv_10 * pi_15;
    std.debug.print("150: R_MA = {d:.6}e+80 (expect > 1e80)\n", .{R_MA * 1e-80});
    
    // Baryon-156: D/H
    const phi_inv_cubed = 1.0 / (PHI * PHI * PHI);
    const D_over_H = phi_inv_cubed * 1e-4;
    std.debug.print("156: D/H = {d:.6}e-5 (expect ~2.5e-5)\n", .{D_over_H * 1e5});
}
