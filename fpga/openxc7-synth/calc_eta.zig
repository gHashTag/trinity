const std = @import("std");
const GAMMA: f64 = 0.23606797749978969641;
const PI: f64 = 3.14159265358979323846;
const PHI: f64 = 1.6180339887498948482;
const E: f64 = 2.718281828459045;

pub fn main() !void {
    const target = 6.09e-10;
    std.debug.print("Target η = {d:.6}e-10\n\n", .{target * 1e10});
    
    // Try different formula combinations
    const gamma_13 = std.math.pow(f64, GAMMA, 13);
    const pi_4 = std.math.pow(f64, PI, 4);
    const phi_7 = std.math.pow(f64, PHI, 7);
    const e_sq = E * E;
    
    const eta1 = gamma_13 * pi_4 / (phi_7 * e_sq);
    std.debug.print("Formula 1: γ¹³ × π⁴ / (φ⁷ × e²) = {d:.6}e-10\n", .{eta1 * 1e10});
    std.debug.print("  Error: {d:.1}%\n\n", .{@abs(eta1 - target) / target * 100.0});
    
    // Try simpler form
    const gamma_14 = std.math.pow(f64, GAMMA, 14);
    const eta2 = gamma_14 * pi_4 / phi_7;
    std.debug.print("Formula 2: γ¹⁴ × π⁴ / φ⁷ = {d:.6}e-10\n", .{eta2 * 1e10});
    std.debug.print("  Error: {d:.1}%\n\n", .{@abs(eta2 - target) / target * 100.0});
    
    // Try with e³
    const gamma_12 = std.math.pow(f64, GAMMA, 12);
    const e_cubed = E * E * E;
    const eta3 = gamma_12 * pi_4 / (phi_7 * e_cubed);
    std.debug.print("Formula 3: γ¹² × π⁴ / (φ⁷ × e³) = {d:.6}e-10\n", .{eta3 * 1e10});
    std.debug.print("  Error: {d:.1}%\n\n", .{@abs(eta3 - target) / target * 100.0});
    
    // What if we use Jarlskog directly?
    // J_CKM = 21γ⁵/(π²φ⁴e²)
    const gamma_5 = std.math.pow(f64, GAMMA, 5);
    const phi_4 = std.math.pow(f64, PHI, 4);
    const pi_sq = PI * PI;
    const J = 21.0 * gamma_5 / (pi_sq * phi_4 * e_sq);
    std.debug.print("J_CKM = {d:.6}e-5\n", .{J * 1e5});
    
    // eta = J × γ⁸ × (suppression)
    const gamma_8 = std.math.pow(f64, GAMMA, 8);
    const eta4 = J * gamma_8 * pi_sq / (PI * PHI);
    std.debug.print("Formula 4: J × γ⁸ × π²/φ = {d:.6}e-10\n", .{eta4 * 1e10});
    std.debug.print("  Error: {d:.1}%\n\n", .{@abs(eta4 - target) / target * 100.0});
    
    // Try eta = γ⁹ × π²/(φ³ × e)
    const gamma_9 = std.math.pow(f64, GAMMA, 9);
    const phi_cubed = PHI * PHI * PHI;
    const eta5 = gamma_9 * pi_sq / (phi_cubed * E);
    std.debug.print("Formula 5: γ⁹ × π² / (φ³ × e) = {d:.6}e-10\n", .{eta5 * 1e10});
    std.debug.print("  Error: {d:.1}%\n", .{@abs(eta5 - target) / target * 100.0});
}
