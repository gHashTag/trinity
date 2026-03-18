const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.718281828459045;

pub fn main() !void {
    // With γ¹⁶
    const gamma_16 = std.math.pow(f64, GAMMA, 16);
    const T_c: f64 = 100.0;
    const pi_sq = PI * PI;
    const e_sq = E * E;
    const Gamma_s = gamma_16 * std.math.pow(f64, T_c, 4) / (pi_sq * e_sq);
    std.debug.print("With γ¹⁶: Γ_s = {d:.6}e-12 GeV (expect < 1e-10)\n", .{Gamma_s * 1e12});
    
    // Try γ¹⁷
    const gamma_17 = std.math.pow(f64, GAMMA, 17);
    const Gamma_s2 = gamma_17 * std.math.pow(f64, T_c, 4) / (pi_sq * e_sq);
    std.debug.print("With γ¹⁷: Γ_s = {d:.6}e-13 GeV\n", .{Gamma_s2 * 1e13});
}
