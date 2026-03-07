const std = @import("std");
const PHI: f64 = 1.6180339887498948482;
const PI: f64 = 3.14159265358979323846;

pub fn main() !void {
    // Current formula: D/H = φ⁻³ × 10⁻⁴
    const phi_inv_cubed = 1.0 / (PHI * PHI * PHI);
    const D_over_H = phi_inv_cubed * 1e-4;
    std.debug.print("Current: φ⁻³ × 10⁻⁴ = {d:.6}e-5\n", .{D_over_H * 1e5});
    std.debug.print("Target: 2.527e-5, error: {d:.1}%\n", .{@abs(D_over_H - 2.527e-5) / 2.527e-5 * 100.0});
    
    // Try: D/H = γ × π × 10⁻⁵
    const GAMMA = 0.23606797749978969641;
    const D_over_H2 = GAMMA * PI * 1e-5;
    std.debug.print("Alternative: γ × π × 10⁻⁵ = {d:.6}e-5\n", .{D_over_H2 * 1e5});
    
    // Try: D/H = 1/φ⁴ × 10⁻³
    const phi_4 = PHI * PHI * PHI * PHI;
    const D_over_H3 = (1.0 / phi_4) * 1e-3;
    std.debug.print("Alternative: φ⁻⁴ × 10⁻³ = {d:.6}e-5\n", .{D_over_H3 * 1e5});
}
