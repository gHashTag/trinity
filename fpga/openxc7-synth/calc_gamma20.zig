const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.718281828459045;

pub fn main() !void {
    const T_c: f64 = 100.0;
    const T_c_4 = std.math.pow(f64, T_c, 4);
    const pi_sq = PI * PI;
    const e_sq = E * E;
    
    // Try γ²⁰
    const gamma_20 = std.math.pow(f64, GAMMA, 20);
    const Gamma_s = gamma_20 * T_c_4 / (pi_sq * e_sq);
    std.debug.print("γ²⁰: Γ_s = {d:.6}e-16 GeV\n", .{Gamma_s * 1e16});
    
    // Try γ²²
    const gamma_22 = std.math.pow(f64, GAMMA, 22);
    const Gamma_s2 = gamma_22 * T_c_4 / (pi_sq * e_sq);
    std.debug.print("γ²²: Γ_s = {d:.6}e-18 GeV (target: <1e-10)\n", .{Gamma_s2 * 1e18});
}
