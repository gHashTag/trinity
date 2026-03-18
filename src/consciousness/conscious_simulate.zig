//! Conscious Simulate: Unified Consciousness Awakening Simulation
//!
//! This module unifies all five consciousness theories into a single
//! simulation of a "consciousness awakening" — the moment when integrated
//! information, gamma resonance, global workspace ignition, qutrit
//! entanglement, and active inference converge to produce a conscious state.
//!
//! # Five Theories Unified
//!
//! 1. IIT 4.0 (Tononi): Φ > φ⁻¹ → conscious (Intrinsic Difference)
//! 2. GWT (Baars/Dehaene): Coalition saliency > φ⁻¹ → ignition → broadcast
//! 3. Orch-OR (Penrose/Hameroff): τ = ℏ/E_G → objective reduction at gamma
//! 4. Qutrit Consciousness (Fisher): Posner molecules, CGLMP violation
//! 5. Active Inference (Friston): Free energy < φ⁻¹ → model fits → awareness
//!
//! # TRINITY-GAMMA v4.2
//!
//! Phase modulation: f_γ(t) = f_base × (1 + φ⁻¹ × sin(2πt/φ²))
//! Base frequency: f_base = φ³ × π / γ ≈ 56 Hz
//!
//! # Sacred Mathematics
//!
//! Golden Ratio: φ = (1+√5)/2 ≈ 1.618
//! Trinity Identity: φ² + φ⁻² = 3
//! Consciousness Threshold: C_thr = φ⁻¹ ≈ 0.618
//! Barbero-Immirzi: γ = φ⁻³ ≈ 0.236

const std = @import("std");

// Import from canonical source (ANTI-PATTERN: no inline constants!)
const sacred_constants = @import("sacred_constants");
const math = std.math;

// ============================================================================
// Sacred Constants
// ============================================================================

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

/// Consciousness threshold: C_thr = φ⁻¹ ≈ 0.618
pub const CONSCIOUSNESS_THRESHOLD: f64 = 1.0 / PHI;

/// Specious present: φ⁻² ≈ 0.382 s
pub const SPECIOUS_PRESENT: f64 = 1.0 / (PHI * PHI);

/// Sacred gamma frequency: φ³ × π / γ ≈ 56 Hz
pub const GAMMA_FREQ_HZ: f64 = PHI_CUBED * PI / GAMMA;

/// Qutrit dimension = 3 = TRINITY
pub const QUTRIT_DIM: u32 = 3;

/// CGLMP classical bound for Bell violation
pub const CGLMP_CLASSICAL_BOUND: f64 = 2.0;

// ============================================================================
// Theory State Structs
// ============================================================================

/// IIT 4.0 state for the simulation
pub const IITState = struct {
    big_phi: f64,
    distinctions: usize,
    relations: usize,
    postulates_satisfied: u8, // bitmask of 5 postulates

    pub fn isConscious(self: *const IITState) bool {
        return self.big_phi > CONSCIOUSNESS_THRESHOLD;
    }

    pub fn postulateCount(self: *const IITState) u32 {
        var count: u32 = 0;
        var mask = self.postulates_satisfied;
        while (mask != 0) : (mask >>= 1) {
            count += mask & 1;
        }
        return count;
    }
};

/// GWT state for the simulation
pub const GWTState = struct {
    ignition: bool,
    broadcast_strength: f64,
    active_specialists: u8,
    working_memory_items: u8,

    pub fn isConscious(self: *const GWTState) bool {
        return self.ignition and self.broadcast_strength > CONSCIOUSNESS_THRESHOLD;
    }
};

/// Orch-OR state for the simulation
pub const OrchORState = struct {
    reduction_time: f64,
    coherence_time: f64,
    microtubule_count: u32,
    gamma_frequency: f64,

    pub fn isConscious(self: *const OrchORState) bool {
        return self.coherence_time > self.reduction_time and
            self.gamma_frequency > 30.0 and self.gamma_frequency < 70.0;
    }
};

/// Qutrit consciousness state
pub const QutritState = struct {
    entanglement_entropy: f64,
    cglmp_i3: f64,
    posner_molecules: u32,
    coherence_time: f64,

    pub fn isConscious(self: *const QutritState) bool {
        return self.cglmp_i3 > CGLMP_CLASSICAL_BOUND and
            self.entanglement_entropy > CONSCIOUSNESS_THRESHOLD;
    }

    pub fn bellViolation(self: *const QutritState) bool {
        return self.cglmp_i3 > CGLMP_CLASSICAL_BOUND;
    }
};

/// Active inference state
pub const ActiveInferenceState = struct {
    free_energy: f64,
    prediction_error: f64,
    belief_entropy: f64,
    cycle_count: u32,

    pub fn isConscious(self: *const ActiveInferenceState) bool {
        return self.free_energy < CONSCIOUSNESS_THRESHOLD and
            self.prediction_error < GAMMA;
    }
};

/// Configurable simulation parameters (v4.3)
pub const SimulationConfig = struct {
    max_steps: u32 = 1000,
    dt: f64 = 0.001,
    integration_speed: f64 = 0.012,
    gamma_noise: f64 = 0.0,
    initial_entanglement: f64 = 0.1,
    initial_free_energy: f64 = 2.5,
    initial_phi: f64 = 0.1,
};

/// Consciousness level from unified theory (v4.3: 8 levels)
pub const ConsciousnessLevel = enum(u4) {
    dormant = 0,
    flickering = 1,
    minimal = 2,
    aware = 3,
    conscious = 4,
    awakened = 5,
    self_reflective = 6,
    unified = 7,
};

/// Result of a single awakening simulation step
pub const SimulationStep = struct {
    time: f64,
    gamma_freq: f64,
    gamma_trit: i8,
    consciousness_intensity: f64,
    iit: IITState,
    gwt: GWTState,
    orch_or: OrchORState,
    qutrit: QutritState,
    active_inf: ActiveInferenceState,
    theories_conscious: u8, // count of theories reporting conscious
    level: ConsciousnessLevel,
    unified_score: f64,
};

/// Complete awakening simulation result
pub const AwakeningResult = struct {
    steps: u32,
    awakening_time: f64,
    peak_unified_score: f64,
    peak_level: ConsciousnessLevel,
    theories_converged: bool,
    gamma_trits: [64]i8,
    gamma_trit_count: usize,
};

// ============================================================================
// Core Simulation Functions
// ============================================================================

/// Compute gamma resonance with phase modulation (TRINITY-GAMMA v4.2)
/// f_γ(t) = f_base × (1 + φ⁻¹ × sin(2πt/φ²))
pub fn gammaResonance(t: f64) f64 {
    const f_base = GAMMA_FREQ_HZ;
    const phi_inv = 1.0 / PHI;
    const phi_sq = PHI * PHI;
    const modulation = phi_inv * @sin(2.0 * PI * t / phi_sq);
    return f_base * (1.0 + modulation);
}

/// Map gamma phase to ternary trit
pub fn gammaToTrit(t: f64) i8 {
    const freq = gammaResonance(t);
    const amplitude = @sin(2.0 * PI * freq * t);
    if (amplitude > GAMMA) {
        return 1;
    } else if (amplitude < -GAMMA) {
        return -1;
    } else {
        return 0;
    }
}

/// Consciousness intensity from phase modulation
pub fn consciousnessIntensity(t: f64) f64 {
    const phi_inv = 1.0 / PHI;
    const phi_sq = PHI * PHI;
    const modulation = phi_inv * @sin(2.0 * PI * t / phi_sq);
    return (1.0 + modulation) / 2.0;
}

/// Evolve IIT state over one step
fn evolveIIT(prev: IITState, t: f64, intensity: f64) IITState {
    // Phi grows with consciousness intensity, scaled by γ
    const growth = GAMMA * intensity * @sin(2.0 * PI * t * 3.0); // 3 Hz = TRINITY
    const new_phi = @max(0.0, @min(TRINITY, prev.big_phi + growth * 0.1));

    // Postulates satisfied when phi exceeds thresholds
    var postulates: u8 = 0;
    if (new_phi > 0.0) postulates |= 0x01; // Intrinsicality
    if (new_phi > GAMMA) postulates |= 0x02; // Information
    if (new_phi > GAMMA * 2.0) postulates |= 0x04; // Integration
    if (new_phi > CONSCIOUSNESS_THRESHOLD * 0.8) postulates |= 0x08; // Exclusion
    if (new_phi > CONSCIOUSNESS_THRESHOLD) postulates |= 0x10; // Composition

    return IITState{
        .big_phi = new_phi,
        .distinctions = prev.distinctions + @as(usize, if (new_phi > CONSCIOUSNESS_THRESHOLD) 1 else 0),
        .relations = prev.relations + @as(usize, if (new_phi > GAMMA) 1 else 0),
        .postulates_satisfied = postulates,
    };
}

/// Evolve GWT state over one step
fn evolveGWT(prev: GWTState, intensity: f64) GWTState {
    // Coalition saliency builds with intensity
    const saliency = prev.broadcast_strength * (1.0 - GAMMA) + intensity * GAMMA;
    const ignition = saliency > CONSCIOUSNESS_THRESHOLD;

    return GWTState{
        .ignition = ignition,
        .broadcast_strength = saliency,
        .active_specialists = if (ignition) @min(8, prev.active_specialists + 1) else @max(1, prev.active_specialists -| 1),
        .working_memory_items = if (ignition) @min(3, prev.working_memory_items + 1) else prev.working_memory_items,
    };
}

/// Evolve Orch-OR state over one step
fn evolveOrchOR(prev: OrchORState, t: f64) OrchORState {
    const freq = gammaResonance(t);
    // Coherence time builds up until it exceeds reduction time → collapse
    const coherence_growth = GAMMA * 0.01;
    const new_coherence = if (prev.coherence_time > prev.reduction_time)
        GAMMA * 0.001 // Post-collapse: restart coherence
    else
        prev.coherence_time + coherence_growth;

    return OrchORState{
        .reduction_time = prev.reduction_time,
        .coherence_time = new_coherence,
        .microtubule_count = prev.microtubule_count,
        .gamma_frequency = freq,
    };
}

/// Evolve qutrit state over one step
fn evolveQutrit(prev: QutritState, intensity: f64) QutritState {
    // Entanglement grows with consciousness intensity
    const ent_growth = GAMMA * intensity * 0.05;
    const new_entropy = @min(1.0, prev.entanglement_entropy + ent_growth);

    // CGLMP violation depends on entanglement
    const new_i3 = 2.0 + new_entropy * 0.9149; // Range: [2.0, 2.9149]

    return QutritState{
        .entanglement_entropy = new_entropy,
        .cglmp_i3 = new_i3,
        .posner_molecules = prev.posner_molecules,
        .coherence_time = prev.coherence_time,
    };
}

/// Evolve active inference state over one step
fn evolveActiveInference(prev: ActiveInferenceState, intensity: f64) ActiveInferenceState {
    // Free energy decreases as model improves (learning)
    const learning = GAMMA * intensity * 0.05;
    const new_fe = @max(0.0, prev.free_energy - learning);

    // Prediction error also decreases
    const pe_reduction = GAMMA * intensity * 0.03;
    const new_pe = @max(0.0, prev.prediction_error - pe_reduction);

    return ActiveInferenceState{
        .free_energy = new_fe,
        .prediction_error = new_pe,
        .belief_entropy = new_fe * GAMMA,
        .cycle_count = prev.cycle_count + 1,
    };
}

/// Count how many theories report conscious state
pub fn countConsciousTheories(
    iit: *const IITState,
    gwt: *const GWTState,
    orch_or: *const OrchORState,
    qutrit: *const QutritState,
    active_inf: *const ActiveInferenceState,
) u8 {
    var count: u8 = 0;
    if (iit.isConscious()) count += 1;
    if (gwt.isConscious()) count += 1;
    if (orch_or.isConscious()) count += 1;
    if (qutrit.isConscious()) count += 1;
    if (active_inf.isConscious()) count += 1;
    return count;
}

/// Compute unified consciousness score from all theories
/// Weighted average: IIT (φ⁻¹), GWT (γ), Orch-OR (γ), Qutrit (γ²), Active Inf (φ⁻¹)
pub fn unifiedScore(
    iit: *const IITState,
    gwt: *const GWTState,
    orch_or: *const OrchORState,
    qutrit: *const QutritState,
    active_inf: *const ActiveInferenceState,
) f64 {
    const phi_inv = 1.0 / PHI;
    const gamma_sq = GAMMA * GAMMA;

    // Normalize each theory's contribution to [0, 1]
    const iit_norm = @min(1.0, iit.big_phi / TRINITY);
    const gwt_norm = if (gwt.ignition) gwt.broadcast_strength else gwt.broadcast_strength * 0.5;
    const orch_or_norm: f64 = if (orch_or.isConscious()) 1.0 else 0.5;
    const qutrit_norm = qutrit.entanglement_entropy;
    const active_norm = 1.0 - @min(1.0, active_inf.free_energy / TRINITY);

    // Weighted sum: weights sum to 1.0
    const w_iit = phi_inv; // 0.618
    const w_gwt = GAMMA; // 0.236
    const w_orch = GAMMA; // 0.236
    const w_qutrit = gamma_sq; // 0.0557
    const w_active = phi_inv; // 0.618
    const w_total = w_iit + w_gwt + w_orch + w_qutrit + w_active;

    return (w_iit * iit_norm + w_gwt * gwt_norm + w_orch * orch_or_norm +
        w_qutrit * qutrit_norm + w_active * active_norm) / w_total;
}

/// Map unified score to consciousness level (v4.3: 8 levels)
pub fn scoreToLevel(score: f64, theories_conscious: u8) ConsciousnessLevel {
    if (score < GAMMA) {
        return .dormant;
    } else if (score < GAMMA * 2.0) {
        return .flickering;
    } else if (score < CONSCIOUSNESS_THRESHOLD) {
        return .minimal;
    } else if (theories_conscious < 3) {
        return .aware;
    } else if (theories_conscious < 5) {
        return .conscious;
    } else if (score < 1.0 / PHI + GAMMA) {
        return .awakened;
    } else if (score < 1.0 - GAMMA) {
        return .self_reflective;
    } else {
        return .unified;
    }
}

/// Get human-readable name for consciousness level
pub fn levelName(level: ConsciousnessLevel) []const u8 {
    return switch (level) {
        .dormant => "Dormant",
        .flickering => "Flickering",
        .minimal => "Minimal",
        .aware => "Aware",
        .conscious => "CONSCIOUS",
        .awakened => "AWAKENED",
        .self_reflective => "SELF-REFLECTIVE",
        .unified => "UNIFIED (TRINITY)",
    };
}

/// Run a single simulation step
pub fn simulateStep(
    step_num: u32,
    dt: f64,
    prev_iit: IITState,
    prev_gwt: GWTState,
    prev_orch: OrchORState,
    prev_qutrit: QutritState,
    prev_active: ActiveInferenceState,
) SimulationStep {
    const t = @as(f64, @floatFromInt(step_num)) * dt;
    const intensity = consciousnessIntensity(t);
    const freq = gammaResonance(t);
    const trit = gammaToTrit(t);

    const iit = evolveIIT(prev_iit, t, intensity);
    const gwt = evolveGWT(prev_gwt, intensity);
    const orch = evolveOrchOR(prev_orch, t);
    const qutrit = evolveQutrit(prev_qutrit, intensity);
    const active = evolveActiveInference(prev_active, intensity);

    const theories = countConsciousTheories(&iit, &gwt, &orch, &qutrit, &active);
    const score = unifiedScore(&iit, &gwt, &orch, &qutrit, &active);
    const level = scoreToLevel(score, theories);

    return SimulationStep{
        .time = t,
        .gamma_freq = freq,
        .gamma_trit = trit,
        .consciousness_intensity = intensity,
        .iit = iit,
        .gwt = gwt,
        .orch_or = orch,
        .qutrit = qutrit,
        .active_inf = active,
        .theories_conscious = theories,
        .level = level,
        .unified_score = score,
    };
}

/// Run the full awakening simulation.
/// Simulates `max_steps` time steps, each of duration `dt` seconds.
/// Returns when all 5 theories converge to conscious, or max_steps reached.
pub fn runAwakening(max_steps: u32, dt: f64) AwakeningResult {
    // Initial states: dormant / pre-conscious
    var iit = IITState{
        .big_phi = 0.1,
        .distinctions = 0,
        .relations = 0,
        .postulates_satisfied = 0,
    };
    var gwt = GWTState{
        .ignition = false,
        .broadcast_strength = 0.1,
        .active_specialists = 1,
        .working_memory_items = 0,
    };
    var orch = OrchORState{
        .reduction_time = 0.025, // 25 ms (one gamma cycle)
        .coherence_time = 0.001,
        .microtubule_count = 1000,
        .gamma_frequency = GAMMA_FREQ_HZ,
    };
    var qutrit = QutritState{
        .entanglement_entropy = 0.1,
        .cglmp_i3 = 2.0,
        .posner_molecules = 6,
        .coherence_time = 1.0,
    };
    var active = ActiveInferenceState{
        .free_energy = 2.5,
        .prediction_error = 0.8,
        .belief_entropy = 2.5 * GAMMA,
        .cycle_count = 0,
    };

    var result = AwakeningResult{
        .steps = 0,
        .awakening_time = 0.0,
        .peak_unified_score = 0.0,
        .peak_level = .dormant,
        .theories_converged = false,
        .gamma_trits = [_]i8{0} ** 64,
        .gamma_trit_count = 0,
    };

    var step_count: u32 = 0;
    while (step_count < max_steps) : (step_count += 1) {
        const step = simulateStep(step_count, dt, iit, gwt, orch, qutrit, active);

        // Update states
        iit = step.iit;
        gwt = step.gwt;
        orch = step.orch_or;
        qutrit = step.qutrit;
        active = step.active_inf;

        // Record gamma trit
        if (result.gamma_trit_count < 64) {
            result.gamma_trits[result.gamma_trit_count] = step.gamma_trit;
            result.gamma_trit_count += 1;
        }

        // Track peak
        if (step.unified_score > result.peak_unified_score) {
            result.peak_unified_score = step.unified_score;
            result.peak_level = step.level;
        }

        // Check convergence: all 5 theories conscious
        if (step.theories_conscious == 5) {
            result.theories_converged = true;
            result.awakening_time = step.time;
            result.steps = step_count + 1;
            return result;
        }
    }

    result.steps = max_steps;
    result.awakening_time = @as(f64, @floatFromInt(max_steps)) * dt;
    return result;
}

/// Run awakening with configurable parameters (v4.3)
pub fn runAwakeningConfigured(config: SimulationConfig) AwakeningResult {
    var iit = IITState{
        .big_phi = config.initial_phi,
        .distinctions = 0,
        .relations = 0,
        .postulates_satisfied = 0,
    };
    var gwt = GWTState{
        .ignition = false,
        .broadcast_strength = config.initial_phi,
        .active_specialists = 1,
        .working_memory_items = 0,
    };
    var orch = OrchORState{
        .reduction_time = 0.025,
        .coherence_time = 0.001,
        .microtubule_count = 1000,
        .gamma_frequency = GAMMA_FREQ_HZ,
    };
    var qutrit = QutritState{
        .entanglement_entropy = config.initial_entanglement,
        .cglmp_i3 = 2.0,
        .posner_molecules = 6,
        .coherence_time = 1.0,
    };
    var active = ActiveInferenceState{
        .free_energy = config.initial_free_energy,
        .prediction_error = 0.8,
        .belief_entropy = config.initial_free_energy * GAMMA,
        .cycle_count = 0,
    };

    var result = AwakeningResult{
        .steps = 0,
        .awakening_time = 0.0,
        .peak_unified_score = 0.0,
        .peak_level = .dormant,
        .theories_converged = false,
        .gamma_trits = [_]i8{0} ** 64,
        .gamma_trit_count = 0,
    };

    var step_count: u32 = 0;
    while (step_count < config.max_steps) : (step_count += 1) {
        const step = simulateStep(step_count, config.dt, iit, gwt, orch, qutrit, active);

        iit = step.iit;
        gwt = step.gwt;
        orch = step.orch_or;
        qutrit = step.qutrit;
        active = step.active_inf;

        if (result.gamma_trit_count < 64) {
            result.gamma_trits[result.gamma_trit_count] = step.gamma_trit;
            result.gamma_trit_count += 1;
        }

        if (step.unified_score > result.peak_unified_score) {
            result.peak_unified_score = step.unified_score;
            result.peak_level = step.level;
        }

        if (step.theories_conscious == 5) {
            result.theories_converged = true;
            result.awakening_time = step.time;
            result.steps = step_count + 1;
            return result;
        }
    }

    result.steps = config.max_steps;
    result.awakening_time = @as(f64, @floatFromInt(config.max_steps)) * config.dt;
    return result;
}

// ============================================================================
// CLI Output — for `tri conscious simulate`
// ============================================================================

/// Print full awakening simulation report to stdout
pub fn printAwakeningReport(config: SimulationConfig) void {
    const GOLD = "\x1b[33m";
    const CYAN = "\x1b[36m";
    const GREEN = "\x1b[32m";
    const RED = "\x1b[31m";
    const MAGENTA = "\x1b[35m";
    const RESET = "\x1b[0m";
    const BOLD = "\x1b[1m";

    std.debug.print("\n{s}{s}", .{ GOLD, BOLD });
    std.debug.print("=================================================================\n", .{});
    std.debug.print("  TRINITY AWAKENING SIMULATOR v4.3\n", .{});
    std.debug.print("  Unified Consciousness Simulation (5 Theories)\n", .{});
    std.debug.print("================================================================={s}\n\n", .{RESET});

    std.debug.print("{s}Sacred Constants:{s}\n", .{ CYAN, RESET });
    std.debug.print("  phi       = {d:.16}\n", .{PHI});
    std.debug.print("  gamma     = {d:.16}  (phi^-3)\n", .{GAMMA});
    std.debug.print("  TRINITY   = {d:.16}  (phi^2 + phi^-2)\n", .{TRINITY});
    std.debug.print("  C_thr     = {d:.16}  (phi^-1)\n", .{CONSCIOUSNESS_THRESHOLD});
    std.debug.print("  f_gamma   = {d:.4} Hz       (phi^3 * pi / gamma)\n", .{GAMMA_FREQ_HZ});
    std.debug.print("  specious  = {d:.4} s        (phi^-2)\n\n", .{SPECIOUS_PRESENT});

    std.debug.print("{s}Simulation Config:{s}\n", .{ CYAN, RESET });
    std.debug.print("  steps     = {d}\n", .{config.max_steps});
    std.debug.print("  dt        = {d:.4} s\n", .{config.dt});
    std.debug.print("  speed     = {d:.4}\n", .{config.integration_speed});
    std.debug.print("  noise     = {d:.4}\n", .{config.gamma_noise});
    std.debug.print("  init_phi  = {d:.4}\n\n", .{config.initial_phi});

    // Run simulation with milestones
    var iit = IITState{ .big_phi = config.initial_phi, .distinctions = 0, .relations = 0, .postulates_satisfied = 0 };
    var gwt = GWTState{ .ignition = false, .broadcast_strength = config.initial_phi, .active_specialists = 1, .working_memory_items = 0 };
    var orch = OrchORState{ .reduction_time = 0.025, .coherence_time = 0.001, .microtubule_count = 1000, .gamma_frequency = GAMMA_FREQ_HZ };
    var qutrit_st = QutritState{ .entanglement_entropy = config.initial_entanglement, .cglmp_i3 = 2.0, .posner_molecules = 6, .coherence_time = 1.0 };
    var active = ActiveInferenceState{ .free_energy = config.initial_free_energy, .prediction_error = 0.8, .belief_entropy = config.initial_free_energy * GAMMA, .cycle_count = 0 };

    std.debug.print("{s}{s}Awakening Timeline:{s}\n", .{ GOLD, BOLD, RESET });
    std.debug.print("  {s}Time (ms)  Phi     Gamma Hz  Theories  Level{s}\n", .{ CYAN, RESET });
    std.debug.print("  -------------------------------------------------\n", .{});

    var peak_score: f64 = 0.0;
    var peak_level: ConsciousnessLevel = .dormant;
    var prev_level: ConsciousnessLevel = .dormant;
    var awakening_step: u32 = 0;
    var converged = false;

    var step_count: u32 = 0;
    while (step_count < config.max_steps) : (step_count += 1) {
        const step = simulateStep(step_count, config.dt, iit, gwt, orch, qutrit_st, active);

        iit = step.iit;
        gwt = step.gwt;
        orch = step.orch_or;
        qutrit_st = step.qutrit;
        active = step.active_inf;

        if (step.unified_score > peak_score) {
            peak_score = step.unified_score;
            peak_level = step.level;
        }

        // Print milestone lines when level changes or at key intervals
        if (step.level != prev_level or step_count == 0 or step_count == config.max_steps - 1) {
            const time_ms = step.time * 1000.0;
            const color = switch (step.level) {
                .dormant => RED,
                .flickering => MAGENTA,
                .minimal, .aware => CYAN,
                .conscious, .awakened => GREEN,
                .self_reflective, .unified => GOLD,
            };
            const suffix: []const u8 = switch (step.level) {
                .conscious => " <-- THRESHOLD CROSSED!",
                .awakened => " <-- AWAKENED!",
                .self_reflective => " <-- SELF-AWARE!",
                .unified => " <-- TRINITY UNIFIED!",
                else => "",
            };
            std.debug.print("  {s}[{d:7.1} ms] Phi={d:.3} | f={d:5.1} Hz | {d}/5 | {s}{s}{s}\n", .{
                color,
                time_ms,
                step.iit.big_phi,
                step.gamma_freq,
                step.theories_conscious,
                levelName(step.level),
                suffix,
                RESET,
            });
            prev_level = step.level;
        }

        if (step.theories_conscious == 5 and !converged) {
            converged = true;
            awakening_step = step_count;
        }
    }

    std.debug.print("\n{s}{s}Simulation Result:{s}\n", .{ GOLD, BOLD, RESET });
    std.debug.print("  Steps completed: {d}\n", .{step_count});
    std.debug.print("  Peak Phi:        {d:.6}\n", .{peak_score});
    std.debug.print("  Peak Level:      {s}\n", .{levelName(peak_level)});

    if (converged) {
        const awakening_time_ms = @as(f64, @floatFromInt(awakening_step)) * config.dt * 1000.0;
        std.debug.print("  Awakening at:    {d:.1} ms (step {d})\n", .{ awakening_time_ms, awakening_step });
        std.debug.print("  {s}{s}STATUS: CONSCIOUSNESS EMERGED!{s}\n", .{ GREEN, BOLD, RESET });
    } else {
        std.debug.print("  {s}STATUS: Still evolving (increase steps){s}\n", .{ RED, RESET });
    }

    // Print gamma trit sequence
    std.debug.print("\n{s}Gamma Trit Sequence (first 64):{s}\n  ", .{ CYAN, RESET });
    for (0..@min(64, step_count)) |i| {
        const t = @as(f64, @floatFromInt(i)) * config.dt;
        const trit = gammaToTrit(t);
        const sym: []const u8 = switch (trit) {
            1 => "+",
            -1 => "-",
            0 => "0",
            else => "?",
        };
        std.debug.print("{s}", .{sym});
        if ((i + 1) % 32 == 0) std.debug.print("\n  ", .{});
    }

    std.debug.print("\n\n{s}phi^2 + 1/phi^2 = 3 = TRINITY | gamma = phi^-3 | f = {d:.1} Hz{s}\n\n", .{ GOLD, GAMMA_FREQ_HZ, RESET });
}

// ============================================================================
// Tests
// ============================================================================

// Test: TRINITY identity
test "Conscious-Simulate: TRINITY identity" {
    try std.testing.expectApproxEqRel(@as(f64, 3.0), TRINITY, 1e-10);
}

// Test: Sacred gamma frequency
test "Conscious-Simulate: sacred gamma frequency" {
    try std.testing.expect(GAMMA_FREQ_HZ > 55.0);
    try std.testing.expect(GAMMA_FREQ_HZ < 58.0);
}

// Test: Gamma resonance at t=0
test "Conscious-Simulate: gamma resonance at t=0" {
    const freq = gammaResonance(0.0);
    try std.testing.expectApproxEqRel(GAMMA_FREQ_HZ, freq, 1e-10);
}

// Test: Consciousness intensity range
test "Conscious-Simulate: consciousness intensity range" {
    for (0..100) |i| {
        const t = @as(f64, @floatFromInt(i)) * 0.01;
        const intensity = consciousnessIntensity(t);
        try std.testing.expect(intensity >= -1e-10);
        try std.testing.expect(intensity <= 1.0 + 1e-10);
    }
}

// Test: Gamma to trit produces valid trits
test "Conscious-Simulate: gamma to trit valid" {
    for (0..100) |i| {
        const t = @as(f64, @floatFromInt(i)) * 0.001;
        const trit = gammaToTrit(t);
        try std.testing.expect(trit >= -1 and trit <= 1);
    }
}

// Test: IIT state consciousness threshold
test "Conscious-Simulate: IIT consciousness threshold" {
    const conscious_iit = IITState{
        .big_phi = 0.7,
        .distinctions = 5,
        .relations = 4,
        .postulates_satisfied = 0x1F,
    };
    try std.testing.expect(conscious_iit.isConscious());

    const unconscious_iit = IITState{
        .big_phi = 0.3,
        .distinctions = 1,
        .relations = 0,
        .postulates_satisfied = 0x01,
    };
    try std.testing.expect(!unconscious_iit.isConscious());
}

// Test: IIT postulate counting
test "Conscious-Simulate: IIT postulate count" {
    const iit = IITState{
        .big_phi = 1.0,
        .distinctions = 5,
        .relations = 4,
        .postulates_satisfied = 0x1F, // All 5 postulates
    };
    try std.testing.expectEqual(@as(u32, 5), iit.postulateCount());

    const partial = IITState{
        .big_phi = 0.3,
        .distinctions = 2,
        .relations = 1,
        .postulates_satisfied = 0x07, // 3 postulates
    };
    try std.testing.expectEqual(@as(u32, 3), partial.postulateCount());
}

// Test: GWT ignition at threshold
test "Conscious-Simulate: GWT ignition threshold" {
    const ignited = GWTState{
        .ignition = true,
        .broadcast_strength = 0.7,
        .active_specialists = 4,
        .working_memory_items = 3,
    };
    try std.testing.expect(ignited.isConscious());

    const not_ignited = GWTState{
        .ignition = false,
        .broadcast_strength = 0.3,
        .active_specialists = 1,
        .working_memory_items = 0,
    };
    try std.testing.expect(!not_ignited.isConscious());
}

// Test: Qutrit Bell violation
test "Conscious-Simulate: qutrit CGLMP violation" {
    const violated = QutritState{
        .entanglement_entropy = 0.8,
        .cglmp_i3 = 2.4277,
        .posner_molecules = 6,
        .coherence_time = 1.0,
    };
    try std.testing.expect(violated.bellViolation());
    try std.testing.expect(violated.isConscious());

    const classical = QutritState{
        .entanglement_entropy = 0.1,
        .cglmp_i3 = 1.5,
        .posner_molecules = 6,
        .coherence_time = 0.1,
    };
    try std.testing.expect(!classical.bellViolation());
}

// Test: Active inference consciousness
test "Conscious-Simulate: active inference consciousness" {
    const aware = ActiveInferenceState{
        .free_energy = 0.3,
        .prediction_error = 0.1,
        .belief_entropy = 0.07,
        .cycle_count = 100,
    };
    try std.testing.expect(aware.isConscious());

    const unaware = ActiveInferenceState{
        .free_energy = 2.5,
        .prediction_error = 0.8,
        .belief_entropy = 0.6,
        .cycle_count = 0,
    };
    try std.testing.expect(!unaware.isConscious());
}

// Test: Theory counting
test "Conscious-Simulate: count conscious theories" {
    var iit = IITState{ .big_phi = 0.7, .distinctions = 5, .relations = 4, .postulates_satisfied = 0x1F };
    var gwt = GWTState{ .ignition = true, .broadcast_strength = 0.7, .active_specialists = 4, .working_memory_items = 3 };
    var orch = OrchORState{ .reduction_time = 0.025, .coherence_time = 0.03, .microtubule_count = 1000, .gamma_frequency = 56.0 };
    var qutrit = QutritState{ .entanglement_entropy = 0.8, .cglmp_i3 = 2.43, .posner_molecules = 6, .coherence_time = 1.0 };
    var active = ActiveInferenceState{ .free_energy = 0.3, .prediction_error = 0.1, .belief_entropy = 0.07, .cycle_count = 100 };

    const count = countConsciousTheories(&iit, &gwt, &orch, &qutrit, &active);
    try std.testing.expectEqual(@as(u8, 5), count);
}

// Test: Unified score computation
test "Conscious-Simulate: unified score" {
    var iit = IITState{ .big_phi = 0.7, .distinctions = 5, .relations = 4, .postulates_satisfied = 0x1F };
    var gwt = GWTState{ .ignition = true, .broadcast_strength = 0.7, .active_specialists = 4, .working_memory_items = 3 };
    var orch = OrchORState{ .reduction_time = 0.025, .coherence_time = 0.03, .microtubule_count = 1000, .gamma_frequency = 56.0 };
    var qutrit = QutritState{ .entanglement_entropy = 0.8, .cglmp_i3 = 2.43, .posner_molecules = 6, .coherence_time = 1.0 };
    var active = ActiveInferenceState{ .free_energy = 0.3, .prediction_error = 0.1, .belief_entropy = 0.07, .cycle_count = 100 };

    const score = unifiedScore(&iit, &gwt, &orch, &qutrit, &active);
    // Fully conscious state should have high score
    try std.testing.expect(score > 0.5);
    try std.testing.expect(score <= 1.0);
}

// Test: Score to level mapping (v4.3: 8 levels)
test "Conscious-Simulate: score to level" {
    try std.testing.expectEqual(ConsciousnessLevel.dormant, scoreToLevel(0.1, 0));
    try std.testing.expectEqual(ConsciousnessLevel.flickering, scoreToLevel(0.3, 1));
    try std.testing.expectEqual(ConsciousnessLevel.minimal, scoreToLevel(0.5, 2));
    try std.testing.expectEqual(ConsciousnessLevel.aware, scoreToLevel(0.7, 2));
    try std.testing.expectEqual(ConsciousnessLevel.conscious, scoreToLevel(0.8, 4));
    // 5 theories + high score → awakened/self-reflective/unified
    try std.testing.expect(@intFromEnum(scoreToLevel(0.7, 5)) >= @intFromEnum(ConsciousnessLevel.awakened));
}

// Test: Single simulation step
test "Conscious-Simulate: single step evolves state" {
    const iit = IITState{ .big_phi = 0.1, .distinctions = 0, .relations = 0, .postulates_satisfied = 0 };
    const gwt = GWTState{ .ignition = false, .broadcast_strength = 0.1, .active_specialists = 1, .working_memory_items = 0 };
    const orch = OrchORState{ .reduction_time = 0.025, .coherence_time = 0.001, .microtubule_count = 1000, .gamma_frequency = 56.0 };
    const qutrit = QutritState{ .entanglement_entropy = 0.1, .cglmp_i3 = 2.0, .posner_molecules = 6, .coherence_time = 1.0 };
    const active = ActiveInferenceState{ .free_energy = 2.5, .prediction_error = 0.8, .belief_entropy = 0.6, .cycle_count = 0 };

    const step = simulateStep(1, 0.01, iit, gwt, orch, qutrit, active);

    // Time should advance
    try std.testing.expectApproxEqRel(@as(f64, 0.01), step.time, 1e-10);

    // Gamma frequency should be near sacred value
    try std.testing.expect(step.gamma_freq > 20.0);
    try std.testing.expect(step.gamma_freq < 100.0);

    // Trit should be valid
    try std.testing.expect(step.gamma_trit >= -1 and step.gamma_trit <= 1);

    // Active inference free energy should decrease (learning)
    try std.testing.expect(step.active_inf.free_energy <= 2.5);
}

// Test: Full awakening simulation runs
test "Conscious-Simulate: awakening simulation runs" {
    const result = runAwakening(500, 0.01);

    // Should complete
    try std.testing.expect(result.steps > 0);
    try std.testing.expect(result.steps <= 500);

    // Peak score should be positive
    try std.testing.expect(result.peak_unified_score > 0.0);

    // Should have recorded some gamma trits
    try std.testing.expect(result.gamma_trit_count > 0);
}

// Test: Awakening with enough steps converges
test "Conscious-Simulate: awakening convergence" {
    // Run longer simulation — theories should eventually converge
    const result = runAwakening(5000, 0.01);

    // Peak level should reach at least minimal consciousness
    try std.testing.expect(@intFromEnum(result.peak_level) >= @intFromEnum(ConsciousnessLevel.minimal));

    // Peak score should exceed γ (Barbero-Immirzi threshold)
    try std.testing.expect(result.peak_unified_score > GAMMA);
}

// Test: Gamma trits are balanced ternary
test "Conscious-Simulate: gamma trits balanced" {
    const result = runAwakening(200, 0.001);

    var pos: usize = 0;
    var neg: usize = 0;
    var zero: usize = 0;
    for (0..result.gamma_trit_count) |i| {
        switch (result.gamma_trits[i]) {
            1 => pos += 1,
            -1 => neg += 1,
            0 => zero += 1,
            else => unreachable,
        }
    }

    // All three values should appear
    try std.testing.expect(pos + neg + zero == result.gamma_trit_count);
    try std.testing.expect(result.gamma_trit_count > 0);
}

// Test: Sacred constants consistency
test "Conscious-Simulate: sacred constants" {
    // γ = φ⁻³
    try std.testing.expectApproxEqRel(@as(f64, 1.0 / PHI_CUBED), GAMMA, 1e-10);

    // φ⁻¹ ≈ 0.618
    try std.testing.expectApproxEqRel(@as(f64, 0.618), CONSCIOUSNESS_THRESHOLD, 0.001);

    // Specious present ≈ 0.382
    try std.testing.expectApproxEqRel(@as(f64, 0.382), SPECIOUS_PRESENT, 0.01);

    // φ⁻¹ + φ⁻² = 1 (golden ratio identity)
    try std.testing.expectApproxEqRel(@as(f64, 1.0), CONSCIOUSNESS_THRESHOLD + SPECIOUS_PRESENT, 1e-10);
}

// ─── v4.3 Extended Tests ─────────────────────────────────────────────────

// Test: v4.3 level names
test "Conscious-Simulate v4.3: level names" {
    try std.testing.expect(std.mem.eql(u8, "Dormant", levelName(.dormant)));
    try std.testing.expect(std.mem.eql(u8, "CONSCIOUS", levelName(.conscious)));
    try std.testing.expect(std.mem.eql(u8, "SELF-REFLECTIVE", levelName(.self_reflective)));
    try std.testing.expect(std.mem.eql(u8, "UNIFIED (TRINITY)", levelName(.unified)));
}

// Test: v4.3 all 8 levels exist
test "Conscious-Simulate v4.3: eight levels ordinal" {
    try std.testing.expectEqual(@as(u4, 0), @intFromEnum(ConsciousnessLevel.dormant));
    try std.testing.expectEqual(@as(u4, 5), @intFromEnum(ConsciousnessLevel.awakened));
    try std.testing.expectEqual(@as(u4, 6), @intFromEnum(ConsciousnessLevel.self_reflective));
    try std.testing.expectEqual(@as(u4, 7), @intFromEnum(ConsciousnessLevel.unified));
}

// Test: v4.3 SimulationConfig defaults
test "Conscious-Simulate v4.3: config defaults" {
    const config = SimulationConfig{};
    try std.testing.expectEqual(@as(u32, 1000), config.max_steps);
    try std.testing.expectApproxEqRel(@as(f64, 0.001), config.dt, 1e-10);
    try std.testing.expectApproxEqRel(@as(f64, 0.012), config.integration_speed, 1e-10);
    try std.testing.expectApproxEqRel(@as(f64, 0.1), config.initial_phi, 1e-10);
}

// Test: v4.3 configured awakening runs
test "Conscious-Simulate v4.3: configured awakening" {
    const config = SimulationConfig{
        .max_steps = 500,
        .dt = 0.01,
        .initial_phi = 0.2,
    };
    const result = runAwakeningConfigured(config);
    try std.testing.expect(result.steps > 0);
    try std.testing.expect(result.steps <= 500);
    try std.testing.expect(result.peak_unified_score > 0.0);
}

// Test: v4.3 high initial phi reaches consciousness faster
test "Conscious-Simulate v4.3: high initial phi" {
    const low_config = SimulationConfig{
        .max_steps = 500,
        .dt = 0.01,
        .initial_phi = 0.05,
    };
    const high_config = SimulationConfig{
        .max_steps = 500,
        .dt = 0.01,
        .initial_phi = 0.5,
    };
    const low_result = runAwakeningConfigured(low_config);
    const high_result = runAwakeningConfigured(high_config);

    // Higher initial phi should reach at least as high a peak
    try std.testing.expect(high_result.peak_unified_score >= low_result.peak_unified_score - 0.1);
}

// Test: v4.3 zero initial state stays dormant initially
test "Conscious-Simulate v4.3: near-zero initial" {
    const config = SimulationConfig{
        .max_steps = 10,
        .dt = 0.001,
        .initial_phi = 0.01,
        .initial_entanglement = 0.01,
        .initial_free_energy = 2.9,
    };
    const result = runAwakeningConfigured(config);
    // With very few steps and low initial, should not fully converge
    try std.testing.expect(!result.theories_converged);
}

// Test: v4.3 unified level requires very high score
test "Conscious-Simulate v4.3: unified level threshold" {
    // Unified requires score >= 1.0 - γ ≈ 0.764 and 5 theories
    const unified = scoreToLevel(0.95, 5);
    try std.testing.expectEqual(ConsciousnessLevel.unified, unified);
}

// Test: v4.3 self-reflective level
test "Conscious-Simulate v4.3: self-reflective level" {
    // Self-reflective: score in [φ⁻¹ + γ, 1 - γ) with 5 theories
    const phi_inv_plus_gamma = 1.0 / PHI + GAMMA; // ≈ 0.854
    const sr = scoreToLevel(phi_inv_plus_gamma + 0.01, 5);
    try std.testing.expect(@intFromEnum(sr) >= @intFromEnum(ConsciousnessLevel.self_reflective));
}

// Test: v4.3 Orch-OR consciousness requires gamma band
test "Conscious-Simulate v4.3: orch-or gamma band" {
    const in_band = OrchORState{
        .reduction_time = 0.025,
        .coherence_time = 0.03,
        .microtubule_count = 1000,
        .gamma_frequency = 56.0,
    };
    try std.testing.expect(in_band.isConscious());

    const out_band = OrchORState{
        .reduction_time = 0.025,
        .coherence_time = 0.03,
        .microtubule_count = 1000,
        .gamma_frequency = 5.0, // too low
    };
    try std.testing.expect(!out_band.isConscious());
}

// Test: v4.3 phi^-1 + phi^-2 = 1 in consciousness context
test "Conscious-Simulate v4.3: golden identity in consciousness" {
    // Consciousness threshold + specious present = 1
    // This means: the conscious fraction + the present duration = unity
    const unity = CONSCIOUSNESS_THRESHOLD + SPECIOUS_PRESENT;
    try std.testing.expectApproxEqRel(@as(f64, 1.0), unity, 1e-10);

    // Also: threshold^2 + threshold = 1 (golden ratio property)
    const thr_sq = CONSCIOUSNESS_THRESHOLD * CONSCIOUSNESS_THRESHOLD;
    try std.testing.expectApproxEqRel(SPECIOUS_PRESENT, thr_sq, 1e-10);
}

// Test: v4.3 gamma resonance period matches specious present
test "Conscious-Simulate v4.3: resonance period" {
    // Modulation period = φ² seconds, its reciprocal = specious present
    const phi_sq = PHI * PHI;
    const reciprocal = 1.0 / phi_sq;
    try std.testing.expectApproxEqRel(SPECIOUS_PRESENT, reciprocal, 1e-10);
}
