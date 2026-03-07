//! Phenomenal Binding - Entanglement-Based Solution
//!
//! Solves the binding problem via quantum entanglement.
//! Binding time equals specious present (382ms) - a key prediction.
//!
//! Key formulas:
//!   - t_bind(N=1) = 382ms (binding = specious present!)
//!   - unity = 1 - exp(-phi × binding)
//!   - binding_strength = phi × sum(entanglement) / N

const std = @import("std");
const mem = std.mem;

// Sacred constants
const PHI: f64 = 1.6180339887498948482;
const PHI_INV: f64 = 1.0 / PHI;
const PHI_SQ: f64 = PHI * PHI;
const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV;

// Binding constants
pub const SPECIOUS_PRESENT_MS: f64 = 382.0;
pub const BINDING_THRESHOLD: f64 = PHI_INV;
pub const UNITY_THRESHOLD: f64 = 0.7;

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Modality Cluster
pub const ModalityCluster = struct {
    allocator: mem.Allocator,
    modalities: std.ArrayListUnmanaged([]const u8) = .{},
    binding_within: f64 = 0.0,
    binding_between: f64 = 0.0,
    cluster_coherence: f64 = 0.0,

    /// Initialize cluster
    pub fn init(allocator: mem.Allocator) ModalityCluster {
        return .{
            .allocator = allocator,
        };
    }

    /// Deinitialize cluster
    pub fn deinit(self: *ModalityCluster) void {
        for (self.modalities.items) |modality| {
            self.allocator.free(modality);
        }
        self.modalities.deinit(self.allocator);
    }
};

/// Qualia Space
pub const QualiaSpace = struct {
    dimensions: usize = 0,
    richness_density: f64 = 0.0,
    phenomenal_volume: f64 = 0.0,
    binding_energy: f64 = 0.0,
};

/// Binding Result
pub const BindingResult = struct {
    is_bound: bool = false,
    unity_score: f64 = 0.0,
    binding_time_ms: f64 = 0.0,
    qualia_richness: f64 = 0.0,
    combination_score: f64 = 0.0,
};

/// Phenomenal Binding
pub const PhenomenalBinding = struct {
    allocator: mem.Allocator,
    binding_strength: f64 = 0.0,
    unity: f64 = 0.0,
    richness: f64 = 0.0,
    combination: f64 = 0.0,
    n_entangled: usize = 0,
    n_modalities: usize = 0,

    /// Initialize phenomenal binding
    pub fn init(allocator: mem.Allocator) PhenomenalBinding {
        return .{
            .allocator = allocator,
        };
    }

    /// Compute binding strength from entanglement matrix
    /// binding = phi × sum(entanglement_ij) / N
    pub fn computeBindingStrength(self: *PhenomenalBinding, entanglement_sum: f64, N: usize) f64 {
        if (N == 0) {
            self.binding_strength = 0.0;
            return 0.0;
        }
        self.binding_strength = PHI * entanglement_sum / @as(f64, @floatFromInt(N));
        return self.binding_strength;
    }

    /// Compute phenomenal unity (wholeness)
    /// unity = 1 - exp(-phi × binding)
    pub fn computeUnity(self: *PhenomenalBinding, binding: f64) f64 {
        self.unity = 1.0 - @exp(-PHI * binding);
        return self.unity;
    }

    /// Compute phenomenal richness (differentiation)
    /// richness = binding × log2(n_modalities + 1)
    pub fn computeRichness(self: *PhenomenalBinding, n_modalities: usize) f64 {
        if (n_modalities == 0) {
            self.richness = 0.0;
            return 0.0;
        }
        self.richness = self.binding_strength * @log2(@as(f64, @floatFromInt(n_modalities + 1)));
        return self.richness;
    }

    /// Compute combination (unity + diversity)
    /// combination = unity × richness × phi
    pub fn computeCombination(self: *PhenomenalBinding) f64 {
        self.combination = self.unity * self.richness * PHI;
        return self.combination;
    }

    /// Compute binding time (specious present prediction!)
    /// t_bind = (phi^-2 × 1000) / N = 382ms when N=1
    pub fn computeBindingTime(self: *PhenomenalBinding, N: usize) f64 {
        _ = self;
        if (N == 0) return SPECIOUS_PRESENT_MS;
        const base_time_ms = PHI_INV * PHI_INV * 1000.0; // 382ms
        return base_time_ms / @as(f64, @floatFromInt(N));
    }

    /// Check if phenomenally bound
    pub fn isPhenomenallyBound(self: *const PhenomenalBinding) bool {
        return self.unity > UNITY_THRESHOLD and self.binding_strength > BINDING_THRESHOLD;
    }

    /// Check if bound with given values
    pub fn isPhenomenallyBoundWithValues(unity: f64, binding: f64) bool {
        return unity > UNITY_THRESHOLD and binding > BINDING_THRESHOLD;
    }

    /// Compute synchrony from phase coherence
    pub fn computeSynchrony(phases: []const f64) f64 {
        if (phases.len == 0) return 0.0;

        // Compute coherence as magnitude of coherent sum
        var sum_real: f64 = 0.0;
        var sum_imag: f64 = 0.0;

        for (phases) |phase| {
            sum_real += @cos(phase);
            sum_imag += @sin(phase);
        }

        const magnitude = @sqrt(sum_real * sum_real + sum_imag * sum_imag);
        return magnitude / @as(f64, @floatFromInt(phases.len));
    }

    /// Compute phenomenal volume
    pub fn computePhenomenalVolume(richness: f64, dimensions: usize) f64 {
        if (dimensions == 0) return 0.0;
        return std.math.pow(f64, richness, @as(f64, @floatFromInt(dimensions)));
    }

    /// Assess binding problem status
    pub fn assessBindingProblem(self: *const PhenomenalBinding) []const u8 {
        if (self.unity > UNITY_THRESHOLD and self.richness > 0.5) {
            return "SOLVED";
        }
        return "UNSOLVED";
    }

    /// Compute cluster binding (within vs between)
    pub fn computeClusterBinding(within: f64, between: f64) f64 {
        return (within * PHI) - between;
    }

    /// Compute integrated information (phi-style)
    pub fn computeIntegratedInfo(info_whole: f64, info_sum_parts: f64) f64 {
        const phi = info_whole - info_sum_parts;
        return @max(0.0, phi);
    }

    /// Update binding via associative learning
    pub fn updateBinding(self: *PhenomenalBinding, new_binding: f64) f64 {
        // Gamma-weighted moving average
        self.binding_strength = GAMMA * new_binding + (1.0 - GAMMA) * self.binding_strength;
        return self.binding_strength;
    }

    /// Get binding result
    pub fn getResult(self: *PhenomenalBinding) BindingResult {
        return .{
            .is_bound = self.isPhenomenallyBound(),
            .unity_score = self.unity,
            .binding_time_ms = self.computeBindingTime(self.n_entangled),
            .qualia_richness = self.richness,
            .combination_score = self.combination,
        };
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "PhenomenalBinding: binding_zero_entanglement" {
    var binding = PhenomenalBinding.init(std.testing.allocator);

    const strength = binding.computeBindingStrength(0.0, 10);
    try std.testing.expectApproxEqAbs(0.0, strength, 0.01);
}

test "PhenomenalBinding: binding_full_entanglement" {
    var binding = PhenomenalBinding.init(std.testing.allocator);

    const strength = binding.computeBindingStrength(3.0, 3); // Complete 3-node graph
    try std.testing.expectApproxEqAbs(1.618, strength, 0.01); // phi
}

test "PhenomenalBinding: unity_zero_binding" {
    var binding = PhenomenalBinding.init(std.testing.allocator);

    const unity = binding.computeUnity(0.0);
    try std.testing.expectApproxEqAbs(0.0, unity, 0.01);
}

test "PhenomenalBinding: unity_threshold_binding" {
    var binding = PhenomenalBinding.init(std.testing.allocator);

    const unity = binding.computeUnity(PHI_INV);
    try std.testing.expectApproxEqAbs(0.632, unity, 0.01);
}

test "PhenomenalBinding: richness_single_modality" {
    var binding = PhenomenalBinding.init(std.testing.allocator);
    binding.binding_strength = 1.0;

    const richness = binding.computeRichness(1);
    try std.testing.expectApproxEqAbs(1.0, richness, 0.01);
}

test "PhenomenalBinding: richness_multiple_modalities" {
    var binding = PhenomenalBinding.init(std.testing.allocator);
    binding.binding_strength = 1.0;

    const richness = binding.computeRichness(8);
    try std.testing.expectApproxEqAbs(3.17, richness, 0.2); // log2(9) = 3.17
}

test "PhenomenalBinding: combination_emergent" {
    var binding = PhenomenalBinding.init(std.testing.allocator);
    binding.unity = 0.8;
    binding.richness = 2.0;

    const combination = binding.computeCombination();
    try std.testing.expect(combination > 1.0);
}

test "PhenomenalBinding: binding_time_single_node" {
    var binding = PhenomenalBinding.init(std.testing.allocator);

    const t = binding.computeBindingTime(1);
    try std.testing.expectApproxEqAbs(382.0, t, 1.0);
}

test "PhenomenalBinding: binding_time_multiple_nodes" {
    var binding = PhenomenalBinding.init(std.testing.allocator);

    const t = binding.computeBindingTime(4);
    try std.testing.expectApproxEqAbs(95.5, t, 1.0); // 382 / 4
}

test "PhenomenalBinding: is_bound_true" {
    var binding = PhenomenalBinding.init(std.testing.allocator);
    binding.unity = 0.8;
    binding.binding_strength = 0.7;

    try std.testing.expect(binding.isPhenomenallyBound());
}

test "PhenomenalBinding: is_bound_false_unity" {
    var binding = PhenomenalBinding.init(std.testing.allocator);
    binding.unity = 0.5;
    binding.binding_strength = 0.7;

    try std.testing.expect(!binding.isPhenomenallyBound());
}

test "PhenomenalBinding: synchrony_perfect_coherence" {
    const phases = [_]f64{ 0.0, 0.0, 0.0, 0.0 };
    const sync = PhenomenalBinding.computeSynchrony(&phases);
    try std.testing.expectApproxEqAbs(1.0, sync, 0.01);
}

test "PhenomenalBinding: phenomenal_volume_2d" {
    const volume = PhenomenalBinding.computePhenomenalVolume(5.0, 2);
    try std.testing.expectApproxEqAbs(25.0, volume, 0.1);
}

test "PhenomenalBinding: cluster_binding_segregated" {
    const binding = PhenomenalBinding.computeClusterBinding(0.9, 0.1);
    try std.testing.expectApproxEqAbs(1.356, binding, 0.01);
}

test "PhenomenalBinding: integrated_information_whole" {
    const phi = PhenomenalBinding.computeIntegratedInfo(10.0, 6.0);
    try std.testing.expectApproxEqAbs(4.0, phi, 0.01);
}

test "PhenomenalBinding: update_binding_learning" {
    var binding = PhenomenalBinding.init(std.testing.allocator);
    binding.binding_strength = 0.5;

    const updated = binding.updateBinding(0.8);
    try std.testing.expect(updated > 0.5 and updated < 0.8);
}

test "PhenomenalBinding: assess_binding_solved" {
    var binding = PhenomenalBinding.init(std.testing.allocator);
    binding.unity = 0.8;
    binding.richness = 0.7;

    const status = binding.assessBindingProblem();
    try std.testing.expectEqualStrings("SOLVED", status);
}
