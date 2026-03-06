//! Chronogeometry: Temporal Geometry via φ and γ
//!
//! This module explores the geometry of spacetime through the lens of
//! φ and γ = φ⁻³.
//!
//! # Mathematical Foundation
//!
//! Golden Ratio:
//!   φ = (1 + √5)/2 ≈ 1.6180339887498948482
//!   γ = φ⁻³ ≈ 0.23606797749978969641
//!
//! Trinity Identity:
//!   φ² + φ⁻² = 3
//!
//! # Hypotheses
//!
//! 1. Spacetime metric has φ-based corrections
//! 2. Closed timelike curves forbidden by γ
//! 3. Specious present duration = φ⁻² seconds
//! 4. Temporal fractal dimension = 1 + γ

const std = @import("std");
const math = std.math;
const mem = std.mem;

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// φ³ = 4.23606797749978969641...
pub const PHI_CUBED: f64 = PHI * PHI * PHI;

/// Barbero-Immirzi parameter γ = φ⁻³
pub const GAMMA: f64 = 1.0 / PHI_CUBED;

/// Fundamental TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

/// π constant
pub const PI: f64 = 3.14159265358979323846;

/// Speed of light (m/s)
pub const C: f64 = 299792458.0;

/// Gravitational constant (m³/kg·s²)
pub const G: f64 = 6.67430e-11;

/// Planck constant (J·s)
pub const H_BAR: f64 = 1.054571817e-34;

/// Spacetime point
pub const SpacetimePoint = struct {
    t: f64, // Time coordinate (s)
    x: f64, // Space x (m)
    y: f64, // Space y (m)
    z: f64, // Space z (m)

    /// Proper time from origin
    pub fn properTime(self: *const SpacetimePoint) f64 {
        const ds_squared = C * C * self.t * self.t - self.x * self.x - self.y * self.y - self.z * self.z;
        if (ds_squared >= 0) {
            return @sqrt(ds_squared) / C;
        } else {
            return 0; // Spacelike separation
        }
    }

    /// Spacetime interval with γ correction
    pub fn intervalGamma(self: *const SpacetimePoint, other: *const SpacetimePoint) f64 {
        const dt = self.t - other.t;
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;

        const gamma_factor = 1.0 + GAMMA * (@abs(dt) * C) / (@sqrt(dx * dx + dy * dy + dz * dz) + 1e-100);
        const ds_squared = C * C * dt * dt * gamma_factor - dx * dx - dy * dy - dz * dz;

        return if (ds_squared >= 0) @sqrt(ds_squared) else -@sqrt(-ds_squared);
    }
};

/// Spacetime metric with φ correction
/// g_μν = η_μν × (1 + γ × curvature_term)
pub const Metric = struct {
    signature: [4]i8, // Metric signature (+,-,-,-) or (-,+,+,+)

    /// Minkowski metric with φ correction
    pub fn minkowskiWithGamma(curvature: f64) [4][4]f64 {
        const eta = [4][4]f64{
           .{1, 0, 0, 0},
            .{0, -1, 0, 0},
            .{0, 0, -1, 0},
            .{0, 0, 0, -1},
        };

        var g = eta;
        const correction = 1.0 + GAMMA * curvature;

        g[0][0] *= correction;
        return g;
    }

    /// Schwarzschild metric with γ correction
    pub fn schwarzschildWithGamma(mass: f64, radius: f64) [4][4]f64 {
        const rs = 2.0 * G * mass / (C * C);
        const gamma_factor = 1.0 + GAMMA * rs / radius;

        return [4][4]f64{
            .{gamma_factor * (1.0 - rs / radius), 0, 0, 0},
            .{0, -1.0 / (1.0 - rs / radius), 0, 0},
            .{0, 0, -radius * radius, 0},
            .{0, 0, 0, -radius * radius * @sin(0) * @sin(0)}, // Simplified (θ=0)
        };
    }
};

/// Temporal fractal dimension
/// D_t = 1 + γ ≈ 1.236
pub fn temporalFractalDimension() f64 {
    return 1.0 + GAMMA;
}

/// Spacetime fractal dimension
/// D_st = 4 - γ ≈ 3.764
pub fn spacetimeFractalDimension() f64 {
    return 4.0 - GAMMA;
}

/// Specious present duration via φ
/// t_present = φ⁻² ≈ 0.382 seconds
pub fn speciousPresent() f64 {
    return 1.0 / (PHI * PHI);
}

/// Temporal horizon via φ
/// Maximum temporal extent of conscious perception
pub fn temporalHorizon() f64 {
    return speciousPresent() * PHI; // ≈ 0.618 seconds
}

/// Worldline parameterization via φ
/// Proper time scales with φ along geodesics
pub const Worldline = struct {
    points: std.ArrayList(SpacetimePoint),
    allocator: mem.Allocator,

    /// Initialize worldline
    pub fn init(allocator: mem.Allocator) Worldline {
        return Worldline{
            .points = .{},
            .allocator = allocator,
        };
    }

    /// Free resources
    pub fn deinit(self: *Worldline) void {
        self.points.deinit(self.allocator);
    }

    /// Add point to worldline
    pub fn addPoint(self: *Worldline, point: SpacetimePoint) !void {
        try self.points.append(self.allocator, point);
    }

    /// Total proper time along worldline
    pub fn properTime(self: *Worldline) f64 {
        if (self.points.items.len < 2) return 0;

        var total: f64 = 0;
        for (1..self.points.items.len) |i| {
            const p1 = &self.points.items[i - 1];
            const p2 = &self.points.items[i];
            const dt = p2.t - p1.t;
            const dx = p2.x - p1.x;
            const dy = p2.y - p1.y;
            const dz = p2.z - p1.z;
            const ds_sq = C * C * dt * dt - dx * dx - dy * dy - dz * dz;
            if (ds_sq > 0) {
                total += @sqrt(ds_sq) / C;
            }
        }
        return total;
    }

    /// φ-weighted proper time
    /// τ_φ = τ × φ for timelike geodesics
    pub fn phiWeightedProperTime(self: *Worldline) f64 {
        return self.properTime() * PHI;
    }
};

/// Chronogeometric measure via φ
/// Distance in spacetime with γ correction
pub fn chronodistance(p1: *const SpacetimePoint, p2: *const SpacetimePoint) f64 {
    const interval = p1.intervalGamma(p2);
    return @abs(interval) * (1.0 + GAMMA);
}

/// Temporal curvature via φ
/// R_t = γ × R where R is Ricci scalar
pub fn temporalCurvature(ricci_scalar: f64) f64 {
    return GAMMA * ricci_scalar;
}

/// Spatial curvature via φ
/// R_s = γ² × R
pub fn spatialCurvature(ricci_scalar: f64) f64 {
    return GAMMA * GAMMA * ricci_scalar;
}

/// Einstein tensor via φ
/// G_μν = R_μν - 1/2 R g_μν with γ corrections
pub fn einsteinTensor(ricci_scalar: f64) [4][4]f64 {
    const gamma_r = temporalCurvature(ricci_scalar);
    const gamma_r2 = spatialCurvature(ricci_scalar);

    return [4][4]f64{
        .{gamma_r, 0, 0, 0},
        .{0, -gamma_r2, 0, 0},
        .{0, 0, -gamma_r2, 0},
        .{0, 0, 0, -gamma_r2},
    };
}

/// Geodesic deviation via γ
/// Separation of nearby geodesics grows with γ factor
pub fn geodesicDeviation(initial_separation: f64, proper_time: f64) f64 {
    return initial_separation * (1.0 + GAMMA * proper_time * C / 1e10);
}

/// Temporal dilation in curved spacetime via φ
/// dτ/dt = √(g_tt) / φ
pub fn temporalDilationCurved(g_tt: f64) f64 {
    return @sqrt(@abs(g_tt)) / PHI;
}

/// Light cone structure via γ
/// Light cone opening angle modified by γ
pub fn lightConeAngle(curvature: f64) f64 {
    const standard = PI / 4.0; // 45 degrees
    return standard * (1.0 - GAMMA * curvature);
}

/// Causal diamond via φ
/// Region of spacetime accessible from an event
pub const CausalDiamond = struct {
    vertex: SpacetimePoint,
    past_extent: f64,
    future_extent: f64,

    /// Volume of causal diamond in 4D
    pub fn volume4D(self: *const CausalDiamond) f64 {
        // 4-volume ∝ R_past × R_future × spatial_volume
        const spatial_vol = 4.0 / 3.0 * PI * std.math.pow(f64, self.past_extent, 3);
        return self.past_extent * self.future_extent * spatial_vol / PHI;
    }

    /// Check if point is inside causal diamond
    pub fn contains(self: *const CausalDiamond, p: *const SpacetimePoint) bool {
        const dt = p.t - self.vertex.t;
        const ddx = p.x - self.vertex.x;
        const ddy = p.y - self.vertex.y;
        const ddz = p.z - self.vertex.z;
        const dr = @sqrt(ddx * ddx + ddy * ddy + ddz * ddz);

        if (dt < 0) {
            // Past light cone
            return @abs(dt) * C >= dr and @abs(dt) <= self.past_extent;
        } else {
            // Future light cone
            return dt * C >= dr and dt <= self.future_extent;
        }
    }
};

/// Closed timelike curve forbidden by γ
/// Check if spacetime region permits CTCs
pub fn permitsCTCs(curvature: f64) bool {
    // γ acts as CTC threshold
    return curvature < GAMMA;
}

/// Wormhole throat radius via φ
/// r_throat = ℓ_P × φ⁴
pub fn wormholeThroatRadius() f64 {
    const planck_length = 1.616255e-35;
    return planck_length * PHI * PHI * PHI * PHI;
}

/// Exotic matter requirement via γ
/// Negative energy density needed for wormhole
pub fn exoticMatterDensity(throat_radius: f64) f64 {
    // ρ_exotic = -γ × c²/(32πGr²)
    return -GAMMA * C * C / (32.0 * PI * G * throat_radius * throat_radius);
}

/// Time machine threshold via γ
/// Minimum exotic energy to create CTC
pub fn timeMachineThreshold(mass: f64) f64 {
    return GAMMA * mass * C * C;
}

// Test: φ³ and γ relationship
test "Chronogeometry: phi cubed and gamma" {
    const phi_cubed_expected = 4.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, phi_cubed_expected), PHI_CUBED, 1e-10);

    const gamma_expected = 0.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, gamma_expected), GAMMA, 1e-10);
}

// Test: TRINITY identity
test "Chronogeometry: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Temporal fractal dimension
test "Chronogeometry: temporal fractal dimension" {
    const d_t = temporalFractalDimension();

    try std.testing.expect(d_t > 1.0);
    try std.testing.expect(d_t < 2.0);
    try std.testing.expectApproxEqRel(@as(f64, 1.236), d_t, 0.1);
}

// Test: Spacetime fractal dimension
test "Chronogeometry: spacetime fractal dimension" {
    const d_st = spacetimeFractalDimension();

    try std.testing.expect(d_st > 3.5);
    try std.testing.expect(d_st < 4.0);
    try std.testing.expectApproxEqRel(@as(f64, 3.764), d_st, 0.1);
}

// Test: Specious present
test "Chronogeometry: specious present" {
    const present = speciousPresent();

    try std.testing.expectApproxEqRel(@as(f64, 0.382), present, 0.1);
}

// Test: Temporal horizon
test "Chronogeometry: temporal horizon" {
    const horizon = temporalHorizon();

    try std.testing.expect(horizon > 0.6);
    try std.testing.expect(horizon < 0.7);
}

// Test: Spacetime point proper time
test "Chronogeometry: proper time" {
    const p = SpacetimePoint{
        .t = 1.0,
        .x = 0,
        .y = 0,
        .z = 0,
    };

    const tau = p.properTime();
    try std.testing.expectApproxEqRel(@as(f64, 1.0), tau, 0.01);
}

// Test: Worldline proper time
test "Chronogeometry: worldline proper time" {
    const allocator = std.testing.allocator;
    var wl = Worldline.init(allocator);
    defer wl.deinit();

    try wl.addPoint(SpacetimePoint{ .t = 0, .x = 0, .y = 0, .z = 0 });
    try wl.addPoint(SpacetimePoint{ .t = 1, .x = 0, .y = 0, .z = 0 });

    const tau = wl.properTime();
    try std.testing.expect(tau > 0.9);
    try std.testing.expect(tau < 1.1);
}

// Test: φ-weighted proper time
test "Chronogeometry: phi weighted proper time" {
    const allocator = std.testing.allocator;
    var wl = Worldline.init(allocator);
    defer wl.deinit();

    try wl.addPoint(SpacetimePoint{ .t = 0, .x = 0, .y = 0, .z = 0 });
    try wl.addPoint(SpacetimePoint{ .t = 1, .x = 0, .y = 0, .z = 0 });

    const tau_phi = wl.phiWeightedProperTime();
    try std.testing.expect(tau_phi > wl.properTime());
}

// Test: Chronodistance
test "Chronogeometry: chronodistance" {
    const p1 = SpacetimePoint{ .t = 0, .x = 0, .y = 0, .z = 0 };
    const p2 = SpacetimePoint{ .t = 1, .x = 0, .y = 0, .z = 0 };

    const dist = chronodistance(&p1, &p2);
    try std.testing.expect(dist > 0);
}

// Test: Causal diamond
test "Chronogeometry: causal diamond" {
    const vertex = SpacetimePoint{ .t = 0, .x = 0, .y = 0, .z = 0 };
    const diamond = CausalDiamond{
        .vertex = vertex,
        .past_extent = 1.0,
        .future_extent = 1.0,
    };

    const inside = SpacetimePoint{ .t = 0.5, .x = 0, .y = 0, .z = 0 };
    const outside = SpacetimePoint{ .t = 2, .x = 0, .y = 0, .z = 0 };

    try std.testing.expect(diamond.contains(&inside));
    try std.testing.expect(!diamond.contains(&outside));
}

// Test: CTC permission
test "Chronogeometry: CTC permission" {
    // curvature < γ (0.236) permits CTCs
    try std.testing.expect(permitsCTCs(0.1));  // 0.1 < 0.236 → true

    // High curvature: no CTCs (curvature > γ threshold)
    try std.testing.expect(!permitsCTCs(10.0));
}

// Test: Wormhole throat radius
test "Chronogeometry: wormhole throat" {
    const r_throat = wormholeThroatRadius();

    // Should be Planck-scale
    try std.testing.expect(r_throat > 1e-36);
    try std.testing.expect(r_throat < 1e-33);
}

// Test: Exotic matter density
test "Chronogeometry: exotic matter" {
    const rho = exoticMatterDensity(1e-10);

    // Should be negative
    try std.testing.expect(rho < 0);
}

// Test: Light cone angle
test "Chronogeometry: light cone angle" {
    const angle = lightConeAngle(0.1);

    // Should be close to π/4
    try std.testing.expect(angle > 0.7);
    try std.testing.expect(angle < 0.9);
}

// Test: Temporal curvature
test "Chronogeometry: temporal curvature" {
    const R_t = temporalCurvature(1.0);

    try std.testing.expect(R_t > 0);
    try std.testing.expect(R_t < GAMMA * 2);
}

// Test: Geodesic deviation
test "Chronogeometry: geodesic deviation" {
    const deviation = geodesicDeviation(1.0, 1e-10);

    try std.testing.expect(deviation > 1.0);
    try std.testing.expect(deviation < 2.0);
}
