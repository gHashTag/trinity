const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.718281828459045;

pub fn main() !void {
    const T_c: f64 = 100.0;
    const T_c_4 = std.math.pow(f64, T_c, 4);
    const pi_sq = PI * PI;
    const e_sq = E * E;
    
    // Try γ²⁵
    const gamma_25 = std.math.pow(f64, GAMMA, 25);
    const Gamma_s = gamma_25 * T_c_4 / (pi_sq * e_sq);
    std.debug.print("γ²⁵: Γ_s = {d:.6}e-12 GeV (<1e-10? {})\n", .{Gamma_s * 1e12, Gamma_s < 1e-10});
    
    // Try γ²⁶
    const gamma_26 = std.math.pow(f64, GAMMA, 26);
    const Gamma_s2 = gamma_26 * T_c_4 / (pi_sq * e_sq);
    std.debug.print("γ²⁶: Γ_s = {d:.6}e-13 GeV (<1e-10? {})\n", .{Gamma_s2 * 1e13, Gamma_s2 < 1e-10});
}
