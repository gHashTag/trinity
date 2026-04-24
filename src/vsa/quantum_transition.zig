//! VSA-Quantum Transition: Quantum-to-Classical via Ternary VSA
//!
//! This module simulates the quantum-to-classical transition using
//! Vector Symbolic Architecture (VSA) with ternary hypervectors.
//!
//! # Mathematical Foundation
//!
//! Quantum Superposition: {-1, 0, +1} trit as qutrit state
//!   |ψ⟩ = α|-1⟩ + β|0⟩ + γ|+1⟩
//!
//! VSA Operations:
//!   - Bind: Association (entanglement)
//!   - Bundle: Superposition (addition)
//!   - Unbind: Retrieval (measurement)
//!
//! γ = φ⁻³ as transition parameter controlling decoherence rate

const std = @import("std");
const math = std.math;
const mem = std.mem;

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// Barbero-Immirzi parameter γ = φ⁻³
pub const GAMMA: f64 = 1.0 / (PHI * PHI * PHI);

/// Fundamental TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI * PHI + 1.0 / (PHI * PHI);

/// Default hypervector dimension (power of 2 for efficiency)
pub const DIM: usize = 1024;

/// Trit (ternary digit) - represents quantum state
pub const Trit = enum(i2) {
    neg = -1, // |−⟩ state
    zero = 0, // |0⟩ state
    pos = 1, // |+⟩ state

    /// Convert to float coefficient
    pub fn toCoefficient(self: Trit) f64 {
        return switch (self) {
            .neg => -1.0,
            .zero => 0.0,
            .pos => 1.0,
        };
    }

    /// Random trit with quantum probability distribution
    pub fn random(rng: *std.Random.DefaultPrng) Trit {
        const r = rng.random().float(f64);
        if (r < 0.333) return .pos;
        if (r < 0.666) return .zero;
        return .neg;
    }
};

/// Quantum hypervector (ternary VSA vector)
pub const QuantumHypervector = struct {
    data: []Trit,
    allocator: mem.Allocator,

    /// Initialize zero hypervector
    pub fn init(allocator: mem.Allocator) !QuantumHypervector {
        const data = try allocator.alloc(Trit, DIM);
        @memset(data, .zero);
        return .{ .data = data, .allocator = allocator };
    }

    /// Initialize random hypervector (quantum superposition)
    pub fn initRandom(allocator: mem.Allocator, rng: *std.Random.DefaultPrng) !QuantumHypervector {
        const hv = try init(allocator);
        for (hv.data) |*t| {
            t.* = Trit.random(rng);
        }
        return hv;
    }

    /// Initialize from quantum state coefficients
    pub fn fromState(allocator: mem.Allocator, coefficients: []const f64) !QuantumHypervector {
        const hv = try init(allocator);
        const len = @min(DIM, coefficients.len);
        for (0..len) |i| {
            const c = coefficients[i];
            if (c > 0.5) hv.data[i] = .pos else if (c < -0.5) hv.data[i] = .neg else hv.data[i] = .zero;
        }
        return hv;
    }

    /// Cleanup
    pub fn deinit(self: *QuantumHypervector) void {
        self.allocator.free(self.data);
    }

    /// Clone hypervector
    pub fn clone(self: *const QuantumHypervector) !QuantumHypervector {
        const hv = try init(self.allocator);
        @memcpy(hv.data, self.data);
        return hv;
    }

    /// Quantum superposition (bundle operation)
    pub fn superpose(self: *const QuantumHypervector, other: *const QuantumHypervector) !QuantumHypervector {
        const result = try init(self.allocator);
        for (0..DIM) |i| {
            const sum = @as(i3, @intFromEnum(self.data[i])) + @as(i3, @intFromEnum(other.data[i]));
            // Majority voting: -2→-1, -1→-1, 0→0, 1→1, 2→1
            result.data[i] = if (sum < 0) .neg else if (sum > 0) .pos else .zero;
        }
        return result;
    }

    /// Quantum entanglement (bind operation via permutation)
    pub fn entangle(self: *const QuantumHypervector, other: *const QuantumHypervector) !QuantumHypervector {
        const result = try self.clone();
        const shift = @as(usize, @intFromFloat(GAMMA * @as(f64, @floatFromInt(DIM))));
        for (0..DIM) |i| {
            const j = (i + shift) % DIM;
            const product = @as(i3, @intFromEnum(self.data[i])) * @as(i3, @intFromEnum(other.data[j]));
            result.data[i] = if (product < 0) .neg else if (product > 0) .pos else .zero;
        }
        return result;
    }

    /// Quantum measurement (collapse to definite state)
    pub fn measure(self: *const QuantumHypervector) !QuantumState {
        var pos_count: usize = 0;
        var neg_count: usize = 0;
        var zero_count: usize = 0;

        for (self.data) |t| {
            switch (t) {
                .pos => pos_count += 1,
                .neg => neg_count += 1,
                .zero => zero_count += 1,
            }
        }

        return QuantumState{
            .pos_prob = @as(f64, @floatFromInt(pos_count)) / @as(f64, @floatFromInt(DIM)),
            .neg_prob = @as(f64, @floatFromInt(neg_count)) / @as(f64, @floatFromInt(DIM)),
            .zero_prob = @as(f64, @floatFromInt(zero_count)) / @as(f64, @floatFromInt(DIM)),
        };
    }

    /// Decoherence operation (quantum → classical transition)
    /// gamma parameter controls decoherence rate
    pub fn decohere(self: *const QuantumHypervector, gamma: f64, steps: usize) !QuantumHypervector {
        var result = try self.clone();
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));

        for (0..steps) |_| {
            // Random trit flips based on γ
            for (0..DIM) |i| {
                if (rng.random().float(f64) < gamma) {
                    // Collapse to definite state
                    if (rng.random().float(f64) < 0.5) {
                        result.data[i] = .pos;
                    } else {
                        result.data[i] = .neg;
                    }
                }
            }
        }
        return result;
    }

    /// Similarity (inner product) - quantum overlap
    pub fn similarity(self: *const QuantumHypervector, other: *const QuantumHypervector) f64 {
        var overlap: i32 = 0;
        for (0..DIM) |i| {
            const a = @as(i3, @intFromEnum(self.data[i]));
            const b = @as(i3, @intFromEnum(other.data[i]));
            overlap += a * b;
        }
        // Normalize to [-1, 1]
        return @as(f64, @floatFromInt(overlap)) / @as(f64, @floatFromInt(DIM));
    }
};

/// Quantum state probability distribution
pub const QuantumState = struct {
    pos_prob: f64,
    neg_prob: f64,
    zero_prob: f64,

    /// Verify normalization
    pub fn isNormalized(self: *const QuantumState) bool {
        const sum = self.pos_prob + self.neg_prob + self.zero_prob;
        return @abs(sum - 1.0) < 0.01;
    }

    /// Expected value
    pub fn expectedValue(self: *const QuantumState) f64 {
        return 1.0 * self.pos_prob + (-1.0) * self.neg_prob + 0.0 * self.zero_prob;
    }
};

/// Quantum system with γ-controlled dynamics
pub const QuantumSystem = struct {
    state: QuantumHypervector,
    gamma: f64,
    coherence: f64,

    /// Initialize quantum system
    pub fn init(allocator: mem.Allocator, gamma: f64) !QuantumSystem {
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        const state = try QuantumHypervector.initRandom(allocator, &rng);
        return .{
            .state = state,
            .gamma = gamma,
            .coherence = 1.0, // Fully coherent
        };
    }

    /// Cleanup
    pub fn deinit(self: *QuantumSystem) void {
        self.state.deinit();
    }

    /// Apply unitary evolution
    pub fn evolve(self: *QuantumSystem) !void {
        // Apply rotation based on γ
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
        for (0..DIM) |i| {
            if (rng.random().float(f64) < self.gamma * 0.1) {
                // Small phase rotation
                const shift: i3 = if (rng.random().float(f64) < 0.5) 1 else -1;
                const current = @as(i3, @intFromEnum(self.state.data[i]));
                const new_val = current +% shift;
                self.state.data[i] = if (new_val < 0) .neg else if (new_val > 0) .pos else .zero;
            }
        }
    }

    /// Apply decoherence (quantum → classical transition)
    pub fn decohere(self: *QuantumSystem) !void {
        // Coherence decreases by γ each step
        self.coherence *= (1.0 - self.gamma);

        if (self.coherence < 0.1) {
            // Full collapse to classical state
            self.state = try self.state.decohere(self.gamma, 10);
        }
    }

    /// Measure system
    pub fn measure(self: *const QuantumSystem) !QuantumState {
        return self.state.measure();
    }
};

// Test: TRINITY identity
test "VSA-Quantum: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Trit coefficient conversion
test "VSA-Quantum: trit coefficients" {
    try std.testing.expectEqual(@as(f64, -1.0), Trit.neg.toCoefficient());
    try std.testing.expectEqual(@as(f64, 0.0), Trit.zero.toCoefficient());
    try std.testing.expectEqual(@as(f64, 1.0), Trit.pos.toCoefficient());
}

// Test: Hypervector initialization
test "VSA-Quantum: hypervector init" {
    var hv = try QuantumHypervector.init(std.testing.allocator);
    defer hv.deinit();

    try std.testing.expectEqual(DIM, hv.data.len);
    for (hv.data) |t| {
        try std.testing.expectEqual(Trit.zero, t);
    }
}

// Test: Quantum superposition (bundle)
test "VSA-Quantum: superposition" {
    var hv1 = try QuantumHypervector.init(std.testing.allocator);
    defer hv1.deinit();
    hv1.data[0] = .pos;

    var hv2 = try QuantumHypervector.init(std.testing.allocator);
    defer hv2.deinit();
    hv2.data[0] = .neg;

    var combined = try hv1.superpose(&hv2);
    defer combined.deinit();

    // pos + neg = zero (cancellation)
    try std.testing.expectEqual(Trit.zero, combined.data[0]);
}

// Test: Quantum measurement
test "VSA-Quantum: measurement" {
    var hv = try QuantumHypervector.init(std.testing.allocator);
    defer hv.deinit();

    // Set specific state
    hv.data[0] = .pos;
    hv.data[1] = .pos;
    hv.data[2] = .neg;
    // Rest are zero

    const state = try hv.measure();

    try std.testing.expect(state.isNormalized());
    try std.testing.expect(state.pos_prob > 0.0);
    try std.testing.expect(state.neg_prob > 0.0);
}

// Test: Decoherence
test "VSA-Quantum: decoherence" {
    var rng = std.Random.DefaultPrng.init(42);
    var hv = try QuantumHypervector.initRandom(std.testing.allocator, &rng);
    defer hv.deinit();

    // Apply decoherence
    var decohered = try hv.decohere(GAMMA, 100);
    defer decohered.deinit();

    // Decohered state should have fewer zeros (more definite)
    var zero_before: usize = 0;
    var zero_after: usize = 0;
    for (hv.data) |t| {
        if (t == .zero) zero_before += 1;
    }
    for (decohered.data) |t| {
        if (t == .zero) zero_after += 1;
    }

    try std.testing.expect(zero_after < zero_before);
}

// Test: Quantum similarity
test "VSA-Quantum: similarity" {
    var rng2 = std.Random.DefaultPrng.init(137);
    var hv1 = try QuantumHypervector.initRandom(std.testing.allocator, &rng2);
    defer hv1.deinit();

    var hv2 = try hv1.clone();
    defer hv2.deinit();

    // Identical vectors should have high similarity
    const sim = hv1.similarity(&hv2);
    // Random vector has ~1/3 each of pos/neg/zero
    // Inner product = pos_count + neg_count (both contribute +1 when squared)
    // Normalized by DIM → ~2/3
    try std.testing.expect(sim > 0.5);
}

// Test: Quantum system evolution
test "VSA-Quantum: system evolution" {
    var system = try QuantumSystem.init(std.testing.allocator, GAMMA);
    defer system.deinit();

    const initial_coherence = system.coherence;

    // Evolve and decohere
    try system.evolve();
    try system.decohere();

    // Coherence should decrease
    try std.testing.expect(system.coherence < initial_coherence);
}

// Test: Expected value
test "VSA-Quantum: expected value" {
    const state = QuantumState{
        .pos_prob = 0.5,
        .neg_prob = 0.3,
        .zero_prob = 0.2,
    };

    const expected = state.expectedValue();
    const manual = 1.0 * 0.5 + (-1.0) * 0.3 + 0.0 * 0.2;

    try std.testing.expectApproxEqRel(manual, expected, 0.01);
}
