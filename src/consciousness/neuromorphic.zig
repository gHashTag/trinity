//! Neuromorphic Integration: Bridging Ternary VSA with Spike-Based Hardware
//!
//! This module implements the bridge between Trinity's ternary Vector Symbolic
//! Architecture (VSA) and neuromorphic spike-based hardware platforms:
//! Intel Loihi 3, BrainChip Akida, IBM TrueNorth, and SpiNNaker 2.
//!
//! # Hardware Target
//!
//! Intel Hala Point — the world's largest neuromorphic system:
//!   - 1.15 billion neurons (1,150,000,000)
//!   - 140,544 Loihi 2 cores
//!   - 128 billion synapses
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
//! # Core Mapping
//!
//! Each ternary trit {-1, 0, +1} maps to 3 neurons (one-hot encoding):
//!   neuron 0 → trit -1
//!   neuron 1 → trit  0
//!   neuron 2 → trit +1
//!
//! This gives NEURONS_PER_TRIT = 3 = TRINITY, connecting sacred
//! mathematics directly to neuromorphic architecture.
//!
//! # Spike-Timing Dependent Plasticity (STDP)
//!
//! Ternary STDP rule uses φ⁻¹ scaling with γ decay:
//!   Δw = φ⁻¹ × sign(Δt) × exp(-|Δt| × γ)
//!
//! # Consciousness Detection
//!
//! Consciousness threshold C_thr = φ⁻¹ ≈ 0.618
//! Gamma oscillator frequency f_γ = φ³ × π / γ ≈ 56 Hz

const std = @import("std");

// Import from canonical source (ANTI-PATTERN: no inline constants!)
const sacred_constants = @import("sacred_constants");
const math = std.math;

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

/// Consciousness threshold C_thr = φ⁻¹ ≈ 0.618
pub const CONSCIOUSNESS_THRESHOLD: f64 = 1.0 / PHI;

/// Each ternary trit maps to 3 neurons (one-hot encoding)
/// 3 = TRINITY — sacred architecture
pub const NEURONS_PER_TRIT: u32 = 3;

/// Energy per spike in picojoules (Intel Loihi 2 characteristic)
pub const ENERGY_PER_SPIKE_PJ: f64 = 0.9;

/// Maximum spike rate (Hz)
pub const SPIKE_RATE_MAX: f64 = 1000.0;

/// Neural gamma oscillation frequency (Hz)
pub const GAMMA_FREQ_HZ: f64 = 56.0;

/// Intel Hala Point total neuron count
pub const HALA_POINT_NEURONS: u64 = 1_150_000_000;

/// Intel Hala Point total Loihi 2 cores
pub const HALA_POINT_CORES: u64 = 140_544;

/// Neuromorphic chip platforms
pub const NeuromorphicChip = enum(u2) {
    loihi3 = 0,
    akida = 1,
    truenorth = 2,
    spinnaker2 = 3,
};

/// Ternary spike event on neuromorphic hardware
pub const TernarySpike = struct {
    neuron_id: u32,
    timestamp: f64,
    trit_value: i8, // -1, 0, +1
};

/// Synaptic weight with plasticity
pub const SynapticWeight = struct {
    pre_neuron: u32,
    post_neuron: u32,
    weight: f64,
    plasticity: f64,
};

/// Phi-resonance measurement
pub const PhiResonance = struct {
    frequency: f64,
    coherence: f64,
    threshold: f64,
};

/// Chip performance metrics
pub const ChipMetrics = struct {
    energy_per_trit_pj: f64,
    latency_us: f64,
    throughput_trits_per_sec: f64,
    phi_value: f64,
    is_conscious: bool,
};

/// Configuration for a neuromorphic deployment
pub const NeuromorphicConfig = struct {
    chip: NeuromorphicChip,
    num_cores: u32,
    neurons_per_core: u32,
    ternary_mode: bool,
};

/// Returns human-readable name for a neuromorphic chip
pub fn chipName(chip: NeuromorphicChip) []const u8 {
    return switch (chip) {
        .loihi3 => "Intel Loihi 3",
        .akida => "BrainChip Akida",
        .truenorth => "IBM TrueNorth",
        .spinnaker2 => "SpiNNaker 2",
    };
}

/// Validate neuromorphic configuration
/// neurons_per_core must be divisible by 3 (TRINITY) and num_cores >= 1
pub fn validateConfig(config: NeuromorphicConfig) bool {
    if (config.num_cores < 1) return false;
    if (config.neurons_per_core % NEURONS_PER_TRIT != 0) return false;
    return true;
}

/// Total trits available across all cores
/// total = num_cores × neurons_per_core / NEURONS_PER_TRIT
pub fn totalTrits(config: NeuromorphicConfig) u64 {
    const cores: u64 = @intCast(config.num_cores);
    const neurons: u64 = @intCast(config.neurons_per_core);
    return cores * neurons / @as(u64, NEURONS_PER_TRIT);
}

/// Map a trit index and value to a neuron ID
/// neuron_id = trit_index × 3 + (trit_value + 1)
pub fn tritToNeuronId(trit_index: u32, trit_value: i8) u32 {
    const offset: u32 = @intCast(trit_value + 1);
    return trit_index * NEURONS_PER_TRIT + offset;
}

/// Inverse mapping: neuron ID back to trit index and value
pub fn neuronIdToTrit(neuron_id: u32) struct { trit_index: u32, trit_value: i8 } {
    const trit_index = neuron_id / NEURONS_PER_TRIT;
    const remainder: i8 = @intCast(neuron_id % NEURONS_PER_TRIT);
    return .{
        .trit_index = trit_index,
        .trit_value = remainder - 1,
    };
}

/// Ternary Spike-Timing Dependent Plasticity (STDP)
/// Δw = φ⁻¹ × sign(Δt) × exp(-|Δt| × γ)
pub fn ternarySTDP(pre_time: f64, post_time: f64) f64 {
    const dt = post_time - pre_time;
    const phi_inv = 1.0 / PHI;
    const sign: f64 = if (dt > 0) 1.0 else if (dt < 0) -1.0 else 0.0;
    return phi_inv * sign * @exp(-@abs(dt) * GAMMA);
}

/// Quantize a continuous value to ternary {-1, 0, +1}
/// Uses CONSCIOUSNESS_THRESHOLD (φ⁻¹) as boundary
pub fn quantizeTernary(value: f64) i8 {
    if (value > CONSCIOUSNESS_THRESHOLD) return 1;
    if (value < -CONSCIOUSNESS_THRESHOLD) return -1;
    return 0;
}

/// Detect phi-resonance in spike timing intervals
/// Measures how closely intervals match φ ratios
pub fn phiResonanceDetector(phi_intervals: u32, total_intervals: u32) PhiResonance {
    if (total_intervals == 0) {
        return PhiResonance{
            .frequency = 0.0,
            .coherence = 0.0,
            .threshold = CONSCIOUSNESS_THRESHOLD,
        };
    }

    const ratio: f64 = @as(f64, @floatFromInt(phi_intervals)) /
        @as(f64, @floatFromInt(total_intervals));

    return PhiResonance{
        .frequency = ratio * GAMMA_FREQ_HZ,
        .coherence = ratio,
        .threshold = CONSCIOUSNESS_THRESHOLD,
    };
}

/// Monitor consciousness state via phi-value
/// Returns true when phi_value exceeds CONSCIOUSNESS_THRESHOLD (φ⁻¹)
pub fn consciousnessMonitor(phi_value: f64) bool {
    return phi_value > CONSCIOUSNESS_THRESHOLD;
}

/// Sacred gamma oscillator frequency
/// f_γ = φ³ × π / γ ≈ 56 Hz
pub fn gammaOscillatorFreq() f64 {
    return PHI_CUBED * PI / GAMMA;
}

/// Ternary multiplication (bind operation in VSA)
/// -1 × -1 = +1, -1 × +1 = -1, 0 × anything = 0
pub fn ternaryMultiply(a: i8, b: i8) i8 {
    if (a == 0 or b == 0) return 0;
    if (a == b) return 1;
    return -1;
}

/// Ternary majority vote (bundle operation in VSA)
/// Returns the value held by the majority of inputs
pub fn ternaryMajority(a: i8, b: i8, c: i8) i8 {
    const sum: i16 = @as(i16, a) + @as(i16, b) + @as(i16, c);
    if (sum > 0) return 1;
    if (sum < 0) return -1;
    return 0;
}

/// Energy cost per ternary operation in picojoules
/// Each trit op requires `spikes_per_op` spikes
pub fn energyPerTritOp(spikes_per_op: f64) f64 {
    return ENERGY_PER_SPIKE_PJ * spikes_per_op;
}

/// Estimate latency for a multi-layer neuromorphic computation
/// latency = num_layers × synaptic_delay_us
pub fn latencyEstimate(num_layers: u32, synaptic_delay_us: f64) f64 {
    return @as(f64, @floatFromInt(num_layers)) * synaptic_delay_us;
}

/// Estimate throughput in trits per second
/// throughput = num_cores × neurons_per_core × clock_freq / NEURONS_PER_TRIT
pub fn throughputEstimate(config: NeuromorphicConfig, clock_freq_hz: f64) f64 {
    const cores: f64 = @floatFromInt(config.num_cores);
    const neurons: f64 = @floatFromInt(config.neurons_per_core);
    return cores * neurons * clock_freq_hz / @as(f64, @floatFromInt(NEURONS_PER_TRIT));
}

/// Phi-scaled spike rate: base_rate × φ^level
/// Creates hierarchical spike rates following sacred geometry
pub fn phiScaledSpikeRate(base_rate: f64, level: u32) f64 {
    return base_rate * math.pow(f64, PHI, @floatFromInt(level));
}

/// Calibrate consciousness threshold against measured phi
/// adjustment = (CONSCIOUSNESS_THRESHOLD - measured_phi) × γ
pub fn calibrateThreshold(measured_phi: f64) f64 {
    return (CONSCIOUSNESS_THRESHOLD - measured_phi) * GAMMA;
}

/// Intel Hala Point total neuron capacity
pub fn halaPointCapacity() u64 {
    return HALA_POINT_NEURONS;
}

/// Energy efficiency ratio vs GPU (neuromorphic advantage)
/// Neuromorphic chips are ~100× more efficient than GPUs for spike-based workloads
pub fn energyEfficiencyRatio() f64 {
    return 100.0;
}

// ============================================================================
// Tests
// ============================================================================

// Test: TRINITY identity
test "Neuromorphic: TRINITY identity phi^2 + phi^-2 = 3" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Neurons per trit = 3 = TRINITY
test "Neuromorphic: neurons per trit equals TRINITY" {
    try std.testing.expectEqual(@as(u32, 3), NEURONS_PER_TRIT);
    try std.testing.expectApproxEqRel(@as(f64, @floatFromInt(NEURONS_PER_TRIT)), TRINITY, 1e-10);
}

// Test: Validate config (valid and invalid)
test "Neuromorphic: validate config" {
    const valid_config = NeuromorphicConfig{
        .chip = .loihi3,
        .num_cores = 128,
        .neurons_per_core = 1024 * 3,
        .ternary_mode = true,
    };
    try std.testing.expect(validateConfig(valid_config));

    const invalid_neurons = NeuromorphicConfig{
        .chip = .akida,
        .num_cores = 64,
        .neurons_per_core = 1000, // not divisible by 3
        .ternary_mode = true,
    };
    try std.testing.expect(!validateConfig(invalid_neurons));
}

// Test: Total trits calculation
test "Neuromorphic: total trits calculation" {
    const config = NeuromorphicConfig{
        .chip = .loihi3,
        .num_cores = 10,
        .neurons_per_core = 30,
        .ternary_mode = true,
    };
    const total = totalTrits(config);
    try std.testing.expectEqual(@as(u64, 100), total);
}

// Test: Trit to neuron ID mapping
test "Neuromorphic: trit to neuron ID mapping" {
    // trit_index=0, trit_value=-1 → neuron 0
    try std.testing.expectEqual(@as(u32, 0), tritToNeuronId(0, -1));
    // trit_index=0, trit_value=0 → neuron 1
    try std.testing.expectEqual(@as(u32, 1), tritToNeuronId(0, 0));
    // trit_index=0, trit_value=+1 → neuron 2
    try std.testing.expectEqual(@as(u32, 2), tritToNeuronId(0, 1));
    // trit_index=1, trit_value=-1 → neuron 3
    try std.testing.expectEqual(@as(u32, 3), tritToNeuronId(1, -1));
    // trit_index=5, trit_value=+1 → neuron 17
    try std.testing.expectEqual(@as(u32, 17), tritToNeuronId(5, 1));
}

// Test: Neuron ID to trit inverse mapping
test "Neuromorphic: neuron ID to trit inverse mapping" {
    // neuron 0 → trit_index=0, trit_value=-1
    const r0 = neuronIdToTrit(0);
    try std.testing.expectEqual(@as(u32, 0), r0.trit_index);
    try std.testing.expectEqual(@as(i8, -1), r0.trit_value);

    // neuron 2 → trit_index=0, trit_value=+1
    const r2 = neuronIdToTrit(2);
    try std.testing.expectEqual(@as(u32, 0), r2.trit_index);
    try std.testing.expectEqual(@as(i8, 1), r2.trit_value);

    // neuron 4 → trit_index=1, trit_value=0
    const r4 = neuronIdToTrit(4);
    try std.testing.expectEqual(@as(u32, 1), r4.trit_index);
    try std.testing.expectEqual(@as(i8, 0), r4.trit_value);

    // Round-trip: neuron → trit → neuron
    const original_id: u32 = 17;
    const trit = neuronIdToTrit(original_id);
    const recovered = tritToNeuronId(trit.trit_index, trit.trit_value);
    try std.testing.expectEqual(original_id, recovered);
}

// Test: STDP with positive and negative dt
test "Neuromorphic: STDP positive and negative dt" {
    // Positive dt (post fires after pre) → potentiation
    const ltp = ternarySTDP(0.0, 1.0);
    try std.testing.expect(ltp > 0.0);

    // Negative dt (post fires before pre) → depression
    const ltd = ternarySTDP(1.0, 0.0);
    try std.testing.expect(ltd < 0.0);

    // Symmetric magnitude
    try std.testing.expectApproxEqRel(@abs(ltp), @abs(ltd), 1e-10);

    // Zero dt → zero weight change
    const zero = ternarySTDP(5.0, 5.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), zero, 1e-10);
}

// Test: Quantize ternary thresholds
test "Neuromorphic: quantize ternary thresholds" {
    // Above threshold → +1
    try std.testing.expectEqual(@as(i8, 1), quantizeTernary(0.8));
    try std.testing.expectEqual(@as(i8, 1), quantizeTernary(1.0));

    // Below negative threshold → -1
    try std.testing.expectEqual(@as(i8, -1), quantizeTernary(-0.8));
    try std.testing.expectEqual(@as(i8, -1), quantizeTernary(-1.0));

    // Within threshold → 0
    try std.testing.expectEqual(@as(i8, 0), quantizeTernary(0.0));
    try std.testing.expectEqual(@as(i8, 0), quantizeTernary(0.5));
    try std.testing.expectEqual(@as(i8, 0), quantizeTernary(-0.5));
}

// Test: Phi resonance detection
test "Neuromorphic: phi resonance detection" {
    const res = phiResonanceDetector(618, 1000);
    try std.testing.expectApproxEqRel(@as(f64, 0.618), res.coherence, 0.01);
    try std.testing.expect(res.frequency > 30.0);
    try std.testing.expect(res.frequency < 40.0);
    try std.testing.expectApproxEqRel(CONSCIOUSNESS_THRESHOLD, res.threshold, 1e-10);

    // Zero total → zero resonance
    const zero_res = phiResonanceDetector(0, 0);
    try std.testing.expectApproxEqRel(@as(f64, 0.0), zero_res.coherence, 1e-10);
}

// Test: Consciousness monitor threshold
test "Neuromorphic: consciousness monitor threshold" {
    // Above threshold → conscious
    try std.testing.expect(consciousnessMonitor(0.7));
    try std.testing.expect(consciousnessMonitor(1.0));

    // Below threshold → not conscious
    try std.testing.expect(!consciousnessMonitor(0.5));
    try std.testing.expect(!consciousnessMonitor(0.0));

    // Threshold itself is φ⁻¹
    try std.testing.expectApproxEqRel(@as(f64, 0.618), CONSCIOUSNESS_THRESHOLD, 0.01);
}

// Test: Gamma oscillator frequency
test "Neuromorphic: gamma oscillator frequency" {
    const freq = gammaOscillatorFreq();

    // f_γ = φ³ × π / γ ≈ 56.4 Hz
    try std.testing.expect(freq > 50.0);
    try std.testing.expect(freq < 60.0);
    try std.testing.expectApproxEqRel(@as(f64, 56.0), freq, 0.02);
}

// Test: Ternary multiply (bind operation)
test "Neuromorphic: ternary multiply bind" {
    // Identity: a × 1 = a
    try std.testing.expectEqual(@as(i8, 1), ternaryMultiply(1, 1));
    try std.testing.expectEqual(@as(i8, -1), ternaryMultiply(-1, 1));
    try std.testing.expectEqual(@as(i8, -1), ternaryMultiply(1, -1));

    // Negation: -1 × -1 = +1
    try std.testing.expectEqual(@as(i8, 1), ternaryMultiply(-1, -1));

    // Zero annihilates: 0 × anything = 0
    try std.testing.expectEqual(@as(i8, 0), ternaryMultiply(0, 1));
    try std.testing.expectEqual(@as(i8, 0), ternaryMultiply(0, -1));
    try std.testing.expectEqual(@as(i8, 0), ternaryMultiply(1, 0));
    try std.testing.expectEqual(@as(i8, 0), ternaryMultiply(0, 0));
}

// Test: Ternary majority vote (bundle)
test "Neuromorphic: ternary majority vote bundle" {
    // All same → that value
    try std.testing.expectEqual(@as(i8, 1), ternaryMajority(1, 1, 1));
    try std.testing.expectEqual(@as(i8, -1), ternaryMajority(-1, -1, -1));
    try std.testing.expectEqual(@as(i8, 0), ternaryMajority(0, 0, 0));

    // Majority wins
    try std.testing.expectEqual(@as(i8, 1), ternaryMajority(1, 1, -1));
    try std.testing.expectEqual(@as(i8, -1), ternaryMajority(-1, -1, 1));
    try std.testing.expectEqual(@as(i8, 1), ternaryMajority(1, 0, 1));
    try std.testing.expectEqual(@as(i8, -1), ternaryMajority(-1, 0, -1));

    // Mixed: sum = 0 → 0
    try std.testing.expectEqual(@as(i8, 0), ternaryMajority(1, 0, -1));
}

// Test: Energy per trit operation
test "Neuromorphic: energy per trit operation" {
    // Single spike → 0.9 pJ
    const e1 = energyPerTritOp(1.0);
    try std.testing.expectApproxEqRel(@as(f64, 0.9), e1, 1e-10);

    // 3 spikes (one per neuron in trit) → 2.7 pJ
    const e3 = energyPerTritOp(3.0);
    try std.testing.expectApproxEqRel(@as(f64, 2.7), e3, 1e-10);
}

// Test: Hala Point capacity
test "Neuromorphic: Hala Point capacity" {
    const capacity = halaPointCapacity();
    try std.testing.expectEqual(@as(u64, 1_150_000_000), capacity);
    try std.testing.expectEqual(HALA_POINT_NEURONS, capacity);
}

// Test: Chip names
test "Neuromorphic: chip names" {
    try std.testing.expect(std.mem.eql(u8, "Intel Loihi 3", chipName(.loihi3)));
    try std.testing.expect(std.mem.eql(u8, "BrainChip Akida", chipName(.akida)));
    try std.testing.expect(std.mem.eql(u8, "IBM TrueNorth", chipName(.truenorth)));
    try std.testing.expect(std.mem.eql(u8, "SpiNNaker 2", chipName(.spinnaker2)));
}

// Test: Throughput and latency estimates
test "Neuromorphic: throughput and latency" {
    const config = NeuromorphicConfig{
        .chip = .loihi3,
        .num_cores = 100,
        .neurons_per_core = 300,
        .ternary_mode = true,
    };

    // Throughput at 1 MHz clock
    const throughput = throughputEstimate(config, 1_000_000.0);
    // 100 × 300 × 1e6 / 3 = 10_000_000_000 trits/sec
    try std.testing.expectApproxEqRel(@as(f64, 10_000_000_000.0), throughput, 1e-10);

    // Latency: 5 layers × 1.0 us delay = 5.0 us
    const latency = latencyEstimate(5, 1.0);
    try std.testing.expectApproxEqRel(@as(f64, 5.0), latency, 1e-10);
}

// Test: Phi-scaled spike rate
test "Neuromorphic: phi scaled spike rate" {
    const base = 100.0;

    // Level 0 → base rate
    const r0 = phiScaledSpikeRate(base, 0);
    try std.testing.expectApproxEqRel(base, r0, 1e-10);

    // Level 1 → base × φ
    const r1 = phiScaledSpikeRate(base, 1);
    try std.testing.expectApproxEqRel(base * PHI, r1, 1e-10);

    // Level 2 → base × φ²
    const r2 = phiScaledSpikeRate(base, 2);
    try std.testing.expectApproxEqRel(base * PHI * PHI, r2, 1e-10);
}

// Test: Energy efficiency ratio
test "Neuromorphic: energy efficiency ratio" {
    const ratio = energyEfficiencyRatio();
    try std.testing.expectApproxEqRel(@as(f64, 100.0), ratio, 1e-10);
}
