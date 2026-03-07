const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const PHI: f64 = 1.6180339887498948482;
const E: f64 = 2.718281828459045;

pub fn main() !void {
    const target = 6.09e-10;
    
    // Calculate J_CKM first
    const gamma_5 = std.math.pow(f64, GAMMA, 5);
    const pi_sq = PI * PI;
    const phi_4 = std.math.pow(f64, PHI, 4);
    const e_sq = E * E;
    
    const J = 21.0 * gamma_5 / (pi_sq * phi_4 * e_sq);
    std.debug.print("J_CKM = 21γ⁵/(π²φ⁴e²) = {d:.6}e-5\n", .{J * 1e5});
    
    // Now compute Formula 4: J × γ⁸ × π²/φ
    const gamma_8 = std.math.pow(f64, GAMMA, 8);
    const eta_formula4 = J * gamma_8 * pi_sq / PHI;
    std.debug.print("Formula 4: J × γ⁸ × π²/φ = {d:.6}e-10 (error: {d:.1}%)\n\n", .{eta_formula4 * 1e10, @abs(eta_formula4 - target) / target * 100.0});
    
    // Now compute the expanded form: 21γ¹³/(φ⁵e²)
    const gamma_13 = std.math.pow(f64, GAMMA, 13);
    const phi_5 = std.math.pow(f64, PHI, 5);
    const eta_expanded = 21.0 * gamma_13 / (phi_5 * e_sq);
    std.debug.print("Expanded: 21γ¹³/(φ⁵e²) = {d:.6}e-10\n", .{eta_expanded * 1e10});
    
    // They should be equal! Let's check:
    std.debug.print("\nAre they equal? {d}\n", .{@abs(eta_formula4 - eta_expanded)});
    
    // Manual verification:
    std.debug.print("\nManual calculation:\n", .{});
    std.debug.print("  γ⁵ = {d:.6}\n", .{gamma_5});
    std.debug.print("  γ⁸ = {d:.6}\n", .{gamma_8});
    std.debug.print("  γ¹³ = {d:.6}\n", .{gamma_13});
    std.debug.print("  π² = {d:.6}\n", .{pi_sq});
    std.debug.print("  φ = {d:.6}\n", .{PHI});
    std.debug.print("  φ⁴ = {d:.6}\n", .{phi_4});
    std.debug.print("  φ⁵ = {d:.6}\n", .{phi_5});
    std.debug.print("  e² = {d:.6}\n", .{e_sq});
    
    // Recalculate Formula 4 manually:
    const manual_f4 = 21.0 * gamma_5 * gamma_8 * pi_sq / (pi_sq * phi_4 * e_sq * PHI);
    std.debug.print("\nManual F4: 21γ⁵×γ⁸×π²/(π²×φ⁴×e²×φ) = {d:.6}e-10\n", .{manual_f4 * 1e10});
    
    // Simplify: π² cancels, γ⁵×γ⁸ = γ¹³, φ⁴×φ = φ⁵
    const simplified = 21.0 * gamma_13 / (phi_5 * e_sq);
    std.debug.print("Simplified: 21γ¹³/(φ⁵e²) = {d:.6}e-10\n", .{simplified * 1e10});
}
