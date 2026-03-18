const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const E: f64 = 2.718281828459045;

pub fn main() !void {
    const T_c: f64 = 100.0;
    const gamma_22 = std.math.pow(f64, GAMMA, 22);
    const T_c_4 = std.math.pow(f64, T_c, 4);
    const pi_sq = PI * PI;
    const e_sq = E * E;
    const Gamma_s = gamma_22 * T_c_4 / (pi_sq * e_sq);
    std.debug.print("Γ_s = {d:.15} GeV\n", .{Gamma_s});
    std.debug.print("Γ_s < 1e-10? {}\n", .{Gamma_s < 1e-10});
    std.debug.print("1e-10 = {d:.15} GeV\n", .{1e-10});
}
