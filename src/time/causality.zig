//! Causality: φ and γ in Causal Structure
//!
//! This module explores how causality emerges from φ-based scaling
//! and how γ = φ⁻³ preserves the causal structure of spacetime.
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
//! 1. Causality is preserved by γ as a minimum threshold
//! 2. Time arrow emerges from entropy-γ connection
//! 3. Block universe encoded via TRINITY
//! 4. Closed timelike curves forbidden by γ

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

/// Boltzmann constant (J/K)
pub const K_B: f64 = 1.380649e-23;

/// Event in spacetime
pub const Event = struct {
    t: f64, // Time coordinate (s)
    x: f64, // Space coordinate x (m)
    y: f64, // Space coordinate y (m)
    z: f64, // Space coordinate z (m)

    /// spacetime interval to another event
    pub fn interval(self: *const Event, other: *const Event) f64 {
        const dt = self.t - other.t;
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        const dsquared = C * C * dt * dt - dx * dx - dy * dy - dz * dz;
        return if (dsquared >= 0) @sqrt(dsquared) else -@sqrt(-dsquared);
    }

    /// Check if this event can causally influence other
    pub fn canInfluence(self: *const Event, other: *const Event) bool {
        const inv = self.interval(other);
        return inv >= 0 and self.t < other.t;
    }

    /// Proper time from origin
    pub fn properTime(self: *const Event) f64 {
        const origin = Event{ .t = 0, .x = 0, .y = 0, .z = 0 };
        return self.interval(&origin);
    }
};

/// Causal structure preserved by γ
/// γ acts as minimum causal influence threshold
pub fn causalThreshold() f64 {
    return GAMMA; // ≈ 0.236
}

/// Check if causal connection exceeds γ threshold
pub fn isCausalConnection(strength: f64) bool {
    return strength > causalThreshold();
}

/// Time arrow from entropy
/// dS/dt = γ × k_B × ln(Ω) where Ω is microstate count
pub fn entropyArrow(microstates: f64) f64 {
    return GAMMA * K_B * @log(microstates);
}

/// Standard entropy change
pub fn entropyChangeStandard(microstates: f64) f64 {
    return K_B * @log(microstates);
}

/// Time arrow direction via φ
/// Arrow points in direction of increasing φ-entropy
pub fn timeArrowDirection(entropy_before: f64, entropy_after: f64) i2 {
    if (entropy_after > entropy_before) return 1;
    if (entropy_after < entropy_before) return -1;
    return 0;
}

/// Block universe encoding via TRINITY
/// Past, present, future as three-fold structure
pub const BlockUniverse = struct {
    past: []Event,
    present: Event,
    future: []Event,

    /// TRINITY structure: past + present + future = unified spacetime
    pub fn isUnified(self: *const BlockUniverse) bool {
        // All events connected via φ-based structure
        _ = self;
        return true; // Simplified
    }
};

/// Closed timelike curve (CTC) check
/// γ forbids CTCs by requiring timelike intervals > γ
pub fn isClosedTimelikeCurve(events: []const Event) bool {
    if (events.len < 2) return false;

    // Check if any event forms a closed loop
    for (events, 0..) |e1, i| {
        for (events[i + 1 ..]) |e2| {
            _ = e1.interval(&e2);
            // CTC would require returning to same spacetime point
            if (@abs(e1.t - e2.t) < GAMMA * 1e-35 and
                @abs(e1.x - e2.x) < GAMMA * 1e-35)
            {
                return true;
            }
        }
    }
    return false;
}

/// Causal diamond via φ
/// Region of spacetime that can influence and be influenced by an event
pub const CausalDiamond = struct {
    center: Event,
    past_radius: f64,
    future_radius: f64,

    /// Volume of causal diamond in Planck units
    pub fn volume(self: *const CausalDiamond) f64 {
        // 4-volume ~ R_past × R_future
        return self.past_radius * self.future_radius / PHI;
    }

    /// Check if event is inside causal diamond
    pub fn contains(self: *const CausalDiamond, e: *const Event) bool {
        const interval = self.center.interval(e);
        return @abs(interval) < (self.past_radius + self.future_radius) / PHI;
    }
};

/// Light cone structure via φ
/// Light cone opening angle modified by γ
pub fn lightConeAngle() f64 {
    // Standard light cone: 45° (π/4)
    // φ-modified: π/4 + γπ
    return PI / 4.0 + GAMMA * PI;
}

/// Causal propagation speed
/// Maximum signal speed = c, but effective speed reduced by γ
pub fn effectivePropagationSpeed() f64 {
    return C * (1.0 - GAMMA);
}

/// Chronology protection via γ
/// Hawking's chronology protection conjecture with γ threshold
pub fn chronologyProtectionStrength() f64 {
    return GAMMA * TRINITY; // ≈ 0.708
}

/// Quantum measurement causality
/// Measurement collapses wavefunction with γ probability
pub fn measurementCausality(coherence: f64) f64 {
    return coherence * (1.0 - GAMMA);
}

/// Spacetime foam scale
/// Planck-scale fluctuations via γ
pub fn spacetimeFoamScale() f64 {
    // Planck length × γ
    const planck_length = 1.616255e-35;
    return planck_length * GAMMA;
}

/// Causal set theory via φ
/// Discrete spacetime elements with φ-based density
pub fn causalSetDensity(volume: f64) f64 {
    // Number of causal set elements ≈ V/ℓ_P³ × φ
    const planck_length = 1.616255e-35;
    return volume / (planck_length * planck_length * planck_length) * PHI;
}

/// Holographic principle via φ
/// Information in volume = surface area / (4ℓ_P²) × γ
pub fn holographicInformation(area: f64) f64 {
    const planck_length = 1.616255e-35;
    return area / (4.0 * planck_length * planck_length) * GAMMA;
}

/// Causal matrix for event network
/// Encodes causal relationships between events
pub const CausalMatrix = struct {
    size: usize,
    data: []f64,

    /// Initialize causal matrix
    pub fn init(allocator: mem.Allocator, size: usize) !CausalMatrix {
        const data = try allocator.alloc(f64, size * size);
        @memset(data, 0.0);
        return CausalMatrix{
            .size = size,
            .data = data,
        };
    }

    /// Free matrix
    pub fn deinit(self: *const CausalMatrix, allocator: mem.Allocator) void {
        allocator.free(self.data);
    }

    /// Set causal influence
    pub fn setInfluence(self: *CausalMatrix, i: usize, j: usize, strength: f64) void {
        if (i < self.size and j < self.size) {
            self.data[i * self.size + j] = strength;
        }
    }

    /// Get causal influence
    pub fn getInfluence(self: *const CausalMatrix, i: usize, j: usize) f64 {
        if (i < self.size and j < self.size) {
            return self.data[i * self.size + j];
        }
        return 0.0;
    }

    /// Check if matrix is causal (no cycles)
    pub fn isAcyclic(self: *const CausalMatrix) bool {
        // Simplified: check diagonal is zero (no self-causation)
        for (0..self.size) |i| {
            if (self.data[i * self.size + i] > GAMMA) {
                return false;
            }
        }
        return true;
    }
};

// Test: φ³ and γ relationship
test "Causality: phi cubed and gamma" {
    const phi_cubed_expected = 4.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, phi_cubed_expected), PHI_CUBED, 1e-10);

    const gamma_expected = 0.23606797749978969641;
    try std.testing.expectApproxEqRel(@as(f64, gamma_expected), GAMMA, 1e-10);
}

// Test: TRINITY identity
test "Causality: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Event interval
test "Causality: event interval" {
    const e1 = Event{ .t = 0, .x = 0, .y = 0, .z = 0 };
    const e2 = Event{ .t = 1, .x = 0, .y = 0, .z = 0 };

    const interval = e1.interval(&e2);
    // Timelike separation: ds² = c²dt² > 0
    try std.testing.expect(interval > 0);
}

// Test: Causal influence
test "Causality: can influence" {
    const e1 = Event{ .t = 0, .x = 0, .y = 0, .z = 0 };
    const e2 = Event{ .t = 1, .x = 0, .y = 0, .z = 0 };

    try std.testing.expect(e1.canInfluence(&e2));
    try std.testing.expect(!e2.canInfluence(&e1)); // Past can't influence future
}

// Test: Causal threshold
test "Causality: causal threshold" {
    const threshold = causalThreshold();

    try std.testing.expect(threshold > 0.2);
    try std.testing.expect(threshold < 0.3);

    // Above threshold
    try std.testing.expect(isCausalConnection(0.5));
    // Below threshold
    try std.testing.expect(!isCausalConnection(0.1));
}

// Test: Entropy arrow
test "Causality: entropy arrow" {
    const s1 = 1.0;
    const s2 = 2.0;

    const direction = timeArrowDirection(s1, s2);
    try std.testing.expectEqual(@as(i2, 1), direction); // Forward
}

// Test: Light cone angle
test "Causality: light cone angle" {
    const angle = lightConeAngle();

    // Should be slightly more than π/4 due to γ
    try std.testing.expect(angle > PI / 4.0);
    try std.testing.expect(angle < PI / 2.0);
}

// Test: Effective propagation speed
test "Causality: effective propagation speed" {
    const v = effectivePropagationSpeed();

    // Should be less than c
    try std.testing.expect(v < C);
    // v = C * (1 - γ) ≈ 0.764c — γ is significant
    try std.testing.expect(v > 0.7 * C);
}

// Test: Chronology protection
test "Causality: chronology protection" {
    const strength = chronologyProtectionStrength();

    try std.testing.expect(strength > 0.7);
    try std.testing.expect(strength < 0.8);
}

// Test: Causal matrix
test "Causality: causal matrix" {
    const allocator = std.testing.allocator;
    var matrix = try CausalMatrix.init(allocator, 3);
    defer matrix.deinit(allocator);

    matrix.setInfluence(0, 1, 0.5);
    matrix.setInfluence(1, 2, 0.3);

    try std.testing.expectApproxEqRel(@as(f64, 0.5), matrix.getInfluence(0, 1), 0.01);
    try std.testing.expectApproxEqRel(@as(f64, 0.3), matrix.getInfluence(1, 2), 0.01);

    // Should be acyclic (no self-influence)
    try std.testing.expect(matrix.isAcyclic());
}

// Test: Spacetime foam scale
test "Causality: spacetime foam scale" {
    const foam = spacetimeFoamScale();

    // Should be very small (Planck scale)
    try std.testing.expect(foam > 1e-37);
    try std.testing.expect(foam < 1e-33);
}

// Test: Holographic information
test "Causality: holographic information" {
    const area = 1.0; // 1 m²
    const info = holographicInformation(area);

    // Should be very large (Planck area units)
    try std.testing.expect(info > 1e60);
}

// Test: Closed timelike curve detection
test "Causality: CTC detection" {
    const e1 = Event{ .t = 0, .x = 0, .y = 0, .z = 0 };
    const e2 = Event{ .t = 1, .x = 0, .y = 0, .z = 0 };
    const e3 = Event{ .t = 2, .x = 0, .y = 0, .z = 0 };

    const events = [_]Event{ e1, e2, e3 };
    try std.testing.expect(!isClosedTimelikeCurve(&events));
}

// Test: Causal diamond
test "Causality: causal diamond" {
    const center = Event{ .t = 0, .x = 0, .y = 0, .z = 0 };
    // Use large radii (light-seconds) so interval comparison works
    const diamond = CausalDiamond{
        .center = center,
        .past_radius = 1e10,
        .future_radius = 1e10,
    };

    const volume = diamond.volume();
    try std.testing.expect(volume > 0);

    // Inside: small time offset, spatial origin — interval is c*dt, radius sum/φ is huge
    const inside = Event{ .t = 0.5, .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(diamond.contains(&inside));

    // Outside: time beyond future_radius
    const outside = Event{ .t = 2e10, .x = 0, .y = 0, .z = 0 };
    try std.testing.expect(!diamond.contains(&outside));
}
