// @origin(spec:consciousness.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Consciousness Gate
// φ⁻¹ threshold on max attention similarity
// Controls System 1 (fast, TNN-only) vs System 2 (slow, VSA reasoning)

const std = @import("std");
const constants = @import("constants.zig");

const PHI_INV = constants.PHI_INV;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSCIOUSNESS GATE
// ═══════════════════════════════════════════════════════════════════════════════

pub const ConsciousnessGate = struct {
    threshold: f64,
    // Exponential moving average of consciousness activation
    ema_activation: f64,
    ema_alpha: f64,
    // Statistics
    total_forward: u64,
    conscious_count: u64,

    const Self = @This();

    pub fn init(threshold: f64) Self {
        return Self{
            .threshold = threshold,
            .ema_activation = 0.0,
            .ema_alpha = 0.1,
            .total_forward = 0,
            .conscious_count = 0,
        };
    }

    pub fn initDefault() Self {
        return init(PHI_INV); // 0.618...
    }

    /// Evaluate consciousness gate
    /// Returns true if System 2 reasoning should be activated
    pub fn isConscious(self: *Self, max_similarity: f64) bool {
        self.total_forward += 1;

        // Update EMA
        self.ema_activation = self.ema_alpha * max_similarity + (1.0 - self.ema_alpha) * self.ema_activation;

        // Gate: activate System 2 when attention is highly focused
        // High similarity means the model is "paying attention" — needs deeper reasoning
        const activated = max_similarity >= self.threshold;
        if (activated) {
            self.conscious_count += 1;
        }
        return activated;
    }

    /// Get consciousness ratio (fraction of time System 2 is active)
    pub fn consciousnessRatio(self: *const Self) f64 {
        if (self.total_forward == 0) return 0.0;
        return @as(f64, @floatFromInt(self.conscious_count)) / @as(f64, @floatFromInt(self.total_forward));
    }

    /// Get smoothed activation level
    pub fn activationLevel(self: *const Self) f64 {
        return self.ema_activation;
    }

    /// Reset statistics
    pub fn resetStats(self: *Self) void {
        self.total_forward = 0;
        self.conscious_count = 0;
        self.ema_activation = 0.0;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// ADAPTIVE COMPUTE BUDGET
// ═══════════════════════════════════════════════════════════════════════════════

/// Determines how many reasoning steps to allocate based on consciousness level
pub fn computeBudget(max_similarity: f64) u8 {
    // Scale reasoning depth by how far above threshold we are
    if (max_similarity < PHI_INV) return 0; // System 1 only
    const excess = max_similarity - PHI_INV;
    // Map 0..0.382 (excess range) to 1..3 reasoning steps
    const steps = @as(u8, @intFromFloat(@min(3.0, 1.0 + excess * 5.26))); // 5.26 ≈ 2/0.382
    return steps;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "consciousness gate default threshold is phi inverse" {
    const gate = ConsciousnessGate.initDefault();
    try std.testing.expectApproxEqAbs(PHI_INV, gate.threshold, 1e-10);
}

test "consciousness gate below threshold" {
    var gate = ConsciousnessGate.initDefault();

    // Low similarity — System 1
    try std.testing.expect(!gate.isConscious(0.3));
    try std.testing.expect(!gate.isConscious(0.5));
    try std.testing.expect(!gate.isConscious(0.617));
}

test "consciousness gate above threshold" {
    var gate = ConsciousnessGate.initDefault();

    // High similarity — System 2
    try std.testing.expect(gate.isConscious(0.62));
    try std.testing.expect(gate.isConscious(0.8));
    try std.testing.expect(gate.isConscious(1.0));
}

test "consciousness ratio tracking" {
    var gate = ConsciousnessGate.initDefault();

    // 3 below + 2 above = 2/5 = 0.4
    _ = gate.isConscious(0.1);
    _ = gate.isConscious(0.2);
    _ = gate.isConscious(0.3);
    _ = gate.isConscious(0.7);
    _ = gate.isConscious(0.9);

    try std.testing.expectApproxEqAbs(0.4, gate.consciousnessRatio(), 1e-10);
}

test "compute budget" {
    // Below threshold
    try std.testing.expect(computeBudget(0.3) == 0);
    try std.testing.expect(computeBudget(0.5) == 0);

    // Above threshold — 1 to 3 steps
    try std.testing.expect(computeBudget(0.62) >= 1);
    try std.testing.expect(computeBudget(0.8) >= 1);
    try std.testing.expect(computeBudget(1.0) >= 1);
    try std.testing.expect(computeBudget(1.0) <= 3);
}
