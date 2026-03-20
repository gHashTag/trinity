//! SACRED WAVE FUNCTION — Bayesian Prior over Θ_sacred
//!
//! ψ(θ) = Σ αᵢ|configᵢ⟩ where αᵢ = probability amplitude
//!
//! Interpretation:
//! - Amplitudes ψ(θ) = posterior weights after measurements
//! - measure_and_update = Bayesian update on categorical distribution
//! - collapse = sampling from |ψ|² (Born rule)
//! - Equivalent to classical Bayesian optimization on discrete lattice
//!
//! References:
//! - [YouTube BO latent] — Bayesian Optimization in Latent Spaces
//! - [arXiv 2510.27091 v1] — Prioritized Policy Optimization
//! - [PMLR Deshwal23a] — Bayesian optimization for categorical spaces
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS
// ═════════════════════════════════════════════════════════════════════════════

/// Golden ratio φ = (1 + √5)/2
pub const PHI: f64 = 1.6180339887498948482;

/// φ² = 2.6180339887498948482...
pub const PHI_SQ: f64 = PHI * PHI;

/// φ⁻¹ = 0.6180339887498948...
pub const PHI_INV: f64 = 1.0 / PHI;

/// TRINITY identity: φ² + φ⁻² = 3
pub const TRINITY: f64 = PHI_SQ + 1.0 / PHI_SQ;

/// Number of sacred configurations (Θ_sacred space size)
/// For HSLM: 6.75M configurations (3^15 based on sacred params)
pub const SACRED_SPACE_SIZE: usize = 6_750_000;

// ═════════════════════════════════════════════════════════════════════════════
// SACRED WAVE FUNCTION
// ═════════════════════════════════════════════════════════════════════════════

/// Wave function over Θ_sacred (6.75M sacred configurations)
/// ψ(θ) = Σ αᵢ|configᵢ⟩ where αᵢ = probability amplitude
///
/// Interpretation:
/// - Amplitudes ψ(θ) = posterior weights after measurements
/// - measure_and_update = Bayesian update on categorical distribution
/// - collapse = sampling from |ψ|² (Born rule)
/// - Equivalent to classical Bayesian optimization on discrete lattice
///
/// References: [YouTube BO latent], [arXiv 2510.27091], [PMLR Deshwal23a]
pub const SacredWaveFunction = struct {
    allocator: std.mem.Allocator,
    /// Probability amplitudes for each sacred config (|ψ|² sums to 1)
    amplitudes: []f64,
    /// Total number of measurements performed
    measurements: usize = 0,
    /// Best PPL observed so far
    best_ppl: f64 = std.math.inf(f64),
    /// Index of best configuration
    best_config: usize = 0,
    /// Inverse temperature β for Bayesian updates
    /// Higher β = stronger response to PPL improvements
    beta: f64 = 1.0,

    /// Initialize uniform superposition (all configs equally probable)
    pub fn initUniform(allocator: std.mem.Allocator, num_configs: usize) !SacredWaveFunction {
        const amplitudes = try allocator.alloc(f64, num_configs);
        const uniform_amp = 1.0 / @sqrt(@as(f64, @floatFromInt(num_configs)));
        @memset(amplitudes, uniform_amp);

        return .{
            .allocator = allocator,
            .amplitudes = amplitudes,
            .beta = 1.0,
        };
    }

    /// Initialize with prior beliefs (non-uniform amplitudes)
    pub fn initWithPrior(allocator: std.mem.Allocator, amplitudes: []f64) !SacredWaveFunction {
        const copied = try allocator.alloc(f64, amplitudes.len);
        @memcpy(copied, amplitudes);

        // Normalize amplitudes
        var total_prob: f64 = 0.0;
        for (amplitudes) |amp| {
            total_prob += amp * amp;
        }
        const norm_factor = if (total_prob > 0) 1.0 / @sqrt(total_prob) else 1.0;

        for (copied) |*amp| {
            amp.* *= norm_factor;
        }

        return .{
            .allocator = allocator,
            .amplitudes = copied,
            .beta = 1.0,
        };
    }

    /// Initialize from previous measurements (experience replay)
    pub fn initFromExperience(
        allocator: std.mem.Allocator,
        experiences: []const struct { config_idx: usize, ppl: f64 },
        num_configs: usize,
    ) !SacredWaveFunction {
        var wave = try initUniform(allocator, num_configs);

        // Update with all past experiences
        for (experiences) |exp| {
            _ = try wave.measureAndUpdate(exp.config_idx, exp.ppl);
        }

        return wave;
    }

    /// Collapse to single configuration via Born rule sampling
    /// Samples from |ψ|² distribution, returns chosen config index
    pub fn collapse(self: *const SacredWaveFunction, rng: anytype) usize {
        // Sample from categorical distribution defined by |ψ|²
        const u = rng.random().float(f64);
        var cumulative: f64 = 0.0;
        for (self.amplitudes, 0..) |amp, i| {
            cumulative += amp * amp; // |ψ|²
            if (u <= cumulative) return i;
        }
        return self.amplitudes.len - 1;
    }

    /// Collapse to best configuration (greedy, not stochastic)
    /// Always selects config with highest |ψ|² (most probable)
    pub fn collapseGreedy(self: *const SacredWaveFunction) usize {
        var max_prob: f64 = 0.0;
        var best_idx: usize = 0;

        for (self.amplitudes, 0..) |amp, i| {
            const prob = amp * amp;
            if (prob > max_prob) {
                max_prob = prob;
                best_idx = i;
            }
        }

        return best_idx;
    }

    /// Bayesian update after measurement
    /// P(θ|data) ∝ P(data|θ) × P(θ)
    /// Lower PPL → higher amplitude (better config more probable)
    pub fn measureAndUpdate(self: *SacredWaveFunction, config_idx: usize, ppl: f64) !void {
        self.measurements += 1;

        // Likelihood: exp(-β × PPL) where β = inverse temperature
        // Uses relative difference from current best for numerical stability
        const best_ppl = if (std.math.isFinite(self.best_ppl)) self.best_ppl else ppl;
        const delta_ppl = ppl - best_ppl;

        const likelihood = @exp(-self.beta * delta_ppl);

        // Bayesian update: amplitude_new ∝ amplitude_old × likelihood
        self.amplitudes[config_idx] *= likelihood;

        // Update best if improved
        if (ppl < self.best_ppl or !std.math.isFinite(self.best_ppl)) {
            self.best_ppl = ppl;
            self.best_config = config_idx;
        }

        // Renormalize to ensure Σ|ψ|² = 1
        try self.normalize();
    }

    /// Renormalize amplitudes so Σ|ψ|² = 1
    fn normalize(self: *SacredWaveFunction) !void {
        var total_prob: f64 = 0.0;
        for (self.amplitudes) |amp| {
            total_prob += amp * amp;
        }

        if (total_prob <= 0) {
            // Fallback: uniform distribution
            const uniform_amp = 1.0 / @sqrt(@as(f64, @floatFromInt(self.amplitudes.len)));
            @memset(self.amplitudes, uniform_amp);
            return;
        }

        const scale = 1.0 / @sqrt(total_prob);
        for (self.amplitudes) |*amp| {
            amp.* *= scale;
        }
    }

    /// Set inverse temperature β (controls exploration vs exploitation)
    /// Higher β = more greedy (exploit known good configs)
    /// Lower β = more explorative (try new configs)
    pub fn setTemperature(self: *SacredWaveFunction, beta: f64) void {
        self.beta = @max(0.01, beta);
    }

    /// Score structure for top configurations
pub const ConfigScore = struct {
    idx: usize,
    prob: f64,
};

/// Get probability for a specific configuration
    /// P(θᵢ) = |ψᵢ|²
    pub fn probability(self: *const SacredWaveFunction, config_idx: usize) f64 {
        if (config_idx >= self.amplitudes.len) return 0.0;
        return self.amplitudes[config_idx] * self.amplitudes[config_idx];
    }

    /// Get top N configurations by probability
    /// Returns array of {idx, probability} tuples
    pub fn topConfigs(self: *const SacredWaveFunction, allocator: std.mem.Allocator, n: usize) ![]ConfigScore {
        var result = try allocator.alloc(ConfigScore, @min(n, self.amplitudes.len));

        for (self.amplitudes, 0..) |amp, i| {
            const prob = amp * amp;

            // Insert into result using insertion sort (small N)
            var j = @min(i, result.len);
            while (j > 0 and result[j - 1].prob < prob) : (j -= 1) {}

            if (j < result.len) {
                // Shift elements
                var k = j;
                while (k < result.len - 1) : (k += 1) {
                    result[k + 1] = result[k];
                }

                result[j] = .{ .idx = i, .prob = prob };
            }
        }

        return result;
    }

    /// Compute Shannon entropy of current distribution
    /// S = -Σ |ψᵢ|² log₂|ψᵢ|²
    pub fn entropy(self: *const SacredWaveFunction) f64 {
        var s: f64 = 0.0;
        for (self.amplitudes) |amp| {
            const prob = amp * amp;
            if (prob > 1e-10) {
                s -= prob * std.math.log2(prob);
            }
        }
        return s;
    }

    /// Check if wave function is collapsed (entropy near zero)
    /// Collapsed = single config dominates (entropy < threshold)
    pub fn isCollapsed(self: *const SacredWaveFunction, threshold: f64) bool {
        const ent = self.entropy();
        return ent < threshold;
    }

    /// Get collapse temperature (when wave function collapses due to repeated measurement)
    /// Higher measurements = higher collapse probability (Quantum Zeno)
    pub fn collapseTemperature(self: *const SacredWaveFunction) f64 {
        // Estimate based on measurements and entropy
        // More measurements with same config → lower entropy → more collapsed
        const max_entropy = std.math.log2(@as(f64, @floatFromInt(self.amplitudes.len)));
        const current_entropy = self.entropy();
        const collapse_ratio = 1.0 - (current_entropy / max_entropy);

        // Temperature drops as wave collapses
        return @max(0.01, 1.0 - collapse_ratio * PHI_INV);
    }

    /// Cleanup
    pub fn deinit(self: *SacredWaveFunction) void {
        self.allocator.free(self.amplitudes);
    }

    /// Format summary for display
    pub fn formatSummary(self: *const SacredWaveFunction, writer: anytype) !void {
        try writer.print("SacredWaveFunction Summary:\n", .{});
        try writer.print("  Total measurements: {d}\n", .{self.measurements});
        try writer.print("  Best PPL: {d:.2}\n", .{self.best_ppl});
        try writer.print("  Best config index: {d}\n", .{self.best_config});
        try writer.print("  Entropy: {d:.4} bits\n", .{self.entropy()});
        try writer.print("  Inverse temperature β: {d:.3}\n", .{self.beta});
        try writer.print("  Collapse temperature: {d:.4}\n", .{self.collapseTemperature()});
        try writer.print("  State: {s}\n", .{if (self.isCollapsed(0.1)) "COLLAPSED" else "SUPERPOSITION"});
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

const testing = std.testing;

test "SacredWaveFunction initUniform normalizes correctly" {
    const num_configs = 100;
    var wave = try SacredWaveFunction.initUniform(testing.allocator, num_configs);
    defer wave.deinit();

    // Check that |ψ|² sums to 1
    var total_prob: f64 = 0.0;
    for (wave.amplitudes) |amp| {
        total_prob += amp * amp;
    }

    try testing.expectApproxEqAbs(@as(f64, 1.0), total_prob, 1e-6);
}

test "SacredWaveFunction collapse samples correctly" {
    var wave = try SacredWaveFunction.initUniform(testing.allocator, 10);
    defer wave.deinit();

    var rng = std.Random.DefaultPrng.init(42);
    const idx = wave.collapse(&rng);

    try testing.expect(idx >= 0 and idx < 10);
}

test "SacredWaveFunction measureAndUpdate updates correctly" {
    var wave = try SacredWaveFunction.initUniform(testing.allocator, 10);
    defer wave.deinit();

    // Initial best is inf
    try testing.expect(!std.math.isFinite(wave.best_ppl));

    // Update with some measurements
    try wave.measureAndUpdate(0, 10.0);
    try testing.expectEqual(@as(usize, 1), wave.measurements);
    try testing.expectApproxEqAbs(@as(f64, 10.0), wave.best_ppl, 1e-6);

    try wave.measureAndUpdate(1, 20.0);
    try wave.measureAndUpdate(2, 5.0);

    // Config 2 should be best (lowest PPL)
    try testing.expectEqual(@as(usize, 3), wave.measurements);
    try testing.expectApproxEqAbs(@as(f64, 5.0), wave.best_ppl, 1e-6);
    try testing.expectEqual(@as(usize, 2), wave.best_config);
}

test "SacredWaveFunction entropy calculation" {
    var wave = try SacredWaveFunction.initUniform(testing.allocator, 4);
    defer wave.deinit();

    // Uniform distribution should have max entropy = log2(4) = 2
    const entropy = wave.entropy();
    try testing.expectApproxEqAbs(@as(f64, 2.0), entropy, 0.01);
}

test "SacredWaveFunction isCollapsed detection" {
    // Uniform = not collapsed
    var uniform = try SacredWaveFunction.initUniform(testing.allocator, 4);
    defer uniform.deinit();

    try testing.expect(!uniform.isCollapsed(0.1));

    // Peaked = collapsed
    var amplitudes = [_]f64{ 0.0, 0.0, 1.0, 0.0 };
    var peaked = try SacredWaveFunction.initWithPrior(testing.allocator, &amplitudes);
    defer peaked.deinit();

    try testing.expect(peaked.isCollapsed(0.1));
}

test "SacredWaveFunction topConfigs returns sorted" {
    var wave = try SacredWaveFunction.initUniform(testing.allocator, 10);
    defer wave.deinit();

    // Update some configs
    try wave.measureAndUpdate(0, 10.0);
    try wave.measureAndUpdate(1, 5.0);
    try wave.measureAndUpdate(2, 3.0);
    try wave.measureAndUpdate(3, 15.0);

    const top3 = try wave.topConfigs(testing.allocator, 3);
    defer testing.allocator.free(top3);

    try testing.expectEqual(@as(usize, 3), top3.len);

    // Should be sorted by probability (descending)
    try testing.expect(top3[0].prob >= top3[1].prob);
    try testing.expect(top3[1].prob >= top3[2].prob);

    // Config 2 (best PPL) should be first
    try testing.expectEqual(@as(usize, 2), top3[0].idx);
}

test "SacredWaveFunction setTemperature affects exploration" {
    var wave = try SacredWaveFunction.initUniform(testing.allocator, 10);
    defer wave.deinit();

    // Set high temperature (more explorative)
    wave.setTemperature(0.1);
    try testing.expectApproxEqAbs(@as(f64, 0.1), wave.beta, 1e-6);

    // Set low temperature (more greedy)
    wave.setTemperature(10.0);
    try testing.expectApproxEqAbs(@as(f64, 10.0), wave.beta, 1e-6);

    // Test min bound
    wave.setTemperature(0.001);
    try testing.expectApproxEqAbs(@as(f64, 0.01), wave.beta, 1e-6);
}

test "TRINITY identity holds" {
    try testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

test "PHI_INV calculation" {
    try testing.expectApproxEqRel(PHI_INV, 1.0 / PHI, 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 0.618), PHI_INV, 0.001);
}

// Version info
pub const VERSION = "1.0.0";
pub const MODULE_NAME = "SACRED WAVE FUNCTION";
