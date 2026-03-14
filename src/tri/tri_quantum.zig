// @origin(spec:tri_quantum.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI CLI - Sacred Quantum v18.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// Quantum consciousness + entanglement + sacred superposition
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const tri_colors = @import("tri_colors.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED QUANTUM CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Reduced Planck constant (ħ = h/(2π))
pub const H_BAR: f64 = 1.054571817e-34;

/// Planck constant
pub const H: f64 = 6.62607015e-34;

/// Fine structure constant (α ≈ 1/137)
pub const ALPHA: f64 = 1.0 / 137.035999084;

/// Golden ratio in quantum mechanics
pub const PHI_QUANTUM: f64 = 1.6180339887498948482;

/// φ-based quantum probability amplitude
pub const PHI_AMPLITUDE: f64 = 1.0 / std.math.sqrt(1.0 + PHI_QUANTUM * PHI_QUANTUM);

/// Sacred coherence time (based on φ)
pub const SACRED_COHERENCE: f64 = PHI_QUANTUM * 1e-3; // seconds

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantum basis states
pub const BasisState = enum {
    zero,
    one,
    plus,
    minus,
    phi,
    phi_perp,

    pub fn name(self: BasisState) []const u8 {
        return switch (self) {
            .zero => "|0⟩",
            .one => "|1⟩",
            .plus => "|+⟩",
            .minus => "|−⟩",
            .phi => "|φ⟩",
            .phi_perp => "|φ⊥⟩",
        };
    }
};

/// Complex number for quantum amplitudes
pub const Complex = struct {
    real: f64,
    imag: f64,

    pub fn init(real: f64, imag: f64) Complex {
        return .{ .real = real, .imag = imag };
    }

    pub fn fromPolar(mag: f64, ph: f64) Complex {
        return .{
            .real = mag * @cos(ph),
            .imag = mag * @sin(ph),
        };
    }

    pub fn magnitude(self: Complex) f64 {
        return std.math.sqrt(self.real * self.real + self.imag * self.imag);
    }

    pub fn phase(self: Complex) f64 {
        return std.math.atan2(self.imag, self.real);
    }

    pub fn format(self: Complex, allocator: std.mem.Allocator) ![]const u8 {
        const imag_sign = if (self.imag >= 0) "+" else "-";
        return std.fmt.allocPrint(allocator, "{d:.3}{s}{d:.3}i", .{ self.real, imag_sign, @abs(self.imag) });
    }
};

/// Quantum state (superposition of basis states)
pub const QuantumState = struct {
    amplitude_zero: Complex,
    amplitude_one: Complex,

    pub fn init(alpha: Complex, beta: Complex) QuantumState {
        // Normalize
        const norm = std.math.sqrt(alpha.magnitude() * alpha.magnitude() + beta.magnitude() * beta.magnitude());
        return .{
            .amplitude_zero = .{ .real = alpha.real / norm, .imag = alpha.imag / norm },
            .amplitude_one = .{ .real = beta.real / norm, .imag = beta.imag / norm },
        };
    }

    pub fn zero() QuantumState {
        return QuantumState.init(Complex.init(1, 0), Complex.init(0, 0));
    }

    pub fn one() QuantumState {
        return QuantumState.init(Complex.init(0, 0), Complex.init(1, 0));
    }

    pub fn plus() QuantumState {
        return QuantumState.init(Complex.init(1.0 / std.math.sqrt(2.0), 0), Complex.init(1.0 / std.math.sqrt(2.0), 0));
    }

    pub fn minus() QuantumState {
        return QuantumState.init(Complex.init(1.0 / std.math.sqrt(2.0), 0), Complex.init(-1.0 / std.math.sqrt(2.0), 0));
    }

    /// Sacred φ-state (golden superposition)
    pub fn phiState() QuantumState {
        const amp = PHI_AMPLITUDE;
        return QuantumState.init(Complex.init(amp, 0), Complex.init(amp * PHI_QUANTUM, 0));
    }

    /// Probability of measuring |0⟩
    pub fn probZero(self: QuantumState) f64 {
        return self.amplitude_zero.magnitude() * self.amplitude_zero.magnitude();
    }

    /// Probability of measuring |1⟩
    pub fn probOne(self: QuantumState) f64 {
        return self.amplitude_one.magnitude() * self.amplitude_one.magnitude();
    }

    /// Entropy of the state
    pub fn entropy(self: QuantumState) f64 {
        const p0 = self.probZero();
        const p1 = self.probOne();
        var result: f64 = 0;
        if (p0 > 0) result -= p0 * std.math.log2(p0);
        if (p1 > 0) result -= p1 * std.math.log2(p1);
        return result;
    }

    /// Check if state is φ-harmonic
    pub fn isPhiHarmonic(self: QuantumState) bool {
        const ratio = self.amplitude_one.magnitude() / self.amplitude_zero.magnitude();
        const diff = @abs(ratio - PHI_QUANTUM);
        return diff < 0.1;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM ENTANGLEMENT
// ═══════════════════════════════════════════════════════════════════════════════

/// Bell states (maximally entangled two-qubit states)
pub const BellState = enum {
    phi_plus, // (|00⟩ + |11⟩)/√2
    phi_minus, // (|00⟩ - |11⟩)/√2
    psi_plus, // (|01⟩ + |10⟩)/√2
    psi_minus, // (|01⟩ - |10⟩)/√2

    pub fn name(self: BellState) []const u8 {
        return switch (self) {
            .phi_plus => "|Φ⁺⟩",
            .phi_minus => "|Φ⁻⟩",
            .psi_plus => "|Ψ⁺⟩",
            .psi_minus => "|Ψ⁻⟩",
        };
    }

    pub fn formula(self: BellState) []const u8 {
        return switch (self) {
            .phi_plus => "(|00⟩ + |11⟩)/√2",
            .phi_minus => "(|00⟩ - |11⟩)/√2",
            .psi_plus => "(|01⟩ + |10⟩)/√2",
            .psi_minus => "(|01⟩ - |10⟩)/√2",
        };
    }
};

/// Entanglement measure
pub const Entanglement = struct {
    concurrence: f64,
    entropy: f64,
    phi_correlation: f64,

    pub fn isSacred(self: Entanglement) bool {
        return self.phi_correlation > 0.9 or self.concurrence > PHI_QUANTUM / 2.0;
    }
};

/// Calculate entanglement between two quantum states
pub fn calculateEntanglement(state1: QuantumState, state2: QuantumState) Entanglement {
    // Simplified concurrence calculation
    const p0_1 = state1.probZero();
    const p1_1 = state1.probOne();
    const p0_2 = state2.probZero();
    const p1_2 = state2.probOne();

    const correlation = @abs(p0_1 * p1_2 - p1_1 * p0_2);
    const concurrence = 2.0 * correlation;
    const entropy = -(p0_1 * std.math.log2(p0_1 + 1e-10) + p1_1 * std.math.log2(p1_1 + 1e-10));

    // φ-correlation based on golden ratio
    const phi_corr = @abs(concurrence - PHI_QUANTUM / 2.0);

    return .{
        .concurrence = concurrence,
        .entropy = entropy,
        .phi_correlation = 1.0 - phi_corr,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM CONSCIOUSNESS
// ═══════════════════════════════════════════════════════════════════════════════

/// Brain-quantum interface metrics
pub const ConsciousnessMetrics = struct {
    quantum_coherence: f64,
    entanglement_degree: f64,
    phi_resonance: f64,
    sacred_state: bool,

    pub fn format(self: ConsciousnessMetrics, allocator: std.mem.Allocator) ![]const u8 {
        const state_str = if (self.sacred_state) "SACRED" else "Ordinary";
        return std.fmt.allocPrint(allocator,
            \\Coherence: {d:.1}%
            \\Entanglement: {d:.1}%
            \\φ-Resonance: {d:.1}%
            \\State: {s}
        , .{ self.quantum_coherence * 100.0, self.entanglement_degree * 100.0, self.phi_resonance * 100.0, state_str });
    }
};

/// Calculate consciousness quantum metrics
pub fn calculateConsciousness(frequency: f64, brain_wave_freq: f64) ConsciousnessMetrics {
    // Coherence based on φ-harmonic relationship
    const ratio = frequency / brain_wave_freq;
    const phi_diff = @abs(ratio - PHI_QUANTUM);
    const coherence = @exp(-phi_diff * phi_diff);

    // Entanglement based on Fibonacci resonance
    const fib_ratio = ratio / @floor(ratio + 0.5);
    const entanglement = if (fib_ratio > 0.5) 1.0 - fib_ratio else fib_ratio;

    // φ-resonance
    const ln_ratio = std.math.log(f64, std.math.e, ratio);
    const ln_phi = std.math.log(f64, std.math.e, PHI_QUANTUM);
    const phi_res = @cos(2.0 * std.math.pi * ln_ratio / ln_phi);
    const phi_resonance = (phi_res + 1.0) / 2.0;

    // Sacred state check
    const sacred_state = coherence > 0.8 and phi_resonance > 0.7;

    return .{
        .quantum_coherence = coherence,
        .entanglement_degree = entanglement,
        .phi_resonance = phi_resonance,
        .sacred_state = sacred_state,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM-MUSIC RESONANCE
// ═══════════════════════════════════════════════════════════════════════════════

/// Quantum musical harmony
pub const QuantumHarmony = struct {
    frequencies: []const f64,
    entanglement_matrix: []const []const f64,
    phi_coherence: f64,

    pub fn deinit(self: *QuantumHarmony, allocator: std.mem.Allocator) void {
        allocator.free(self.frequencies);
        for (self.entanglement_matrix) |row| {
            allocator.free(row);
        }
        allocator.free(self.entanglement_matrix);
    }
};

/// Calculate quantum resonance between musical frequencies
pub fn quantumMusicResonance(freqs: []const f64, allocator: std.mem.Allocator) !QuantumHarmony {
    const n = freqs.len;

    // Create entanglement matrix
    const matrix = try allocator.alloc([]f64, n);
    for (0..n) |i| {
        matrix[i] = try allocator.alloc(f64, n);
        for (0..n) |j| {
            if (i == j) {
                matrix[i][j] = 1.0;
            } else {
                const ratio = freqs[i] / freqs[j];
                const ln_ratio = std.math.log(f64, std.math.e, ratio);
                const ln_phi = std.math.log(f64, std.math.e, PHI_QUANTUM);
                const log_ratio = @abs(ln_ratio / ln_phi);
                const phi_entanglement = @exp(-log_ratio * log_ratio);
                matrix[i][j] = phi_entanglement;
            }
        }
    }

    // Calculate overall φ-coherence
    var total_phi: f64 = 0;
    var count: usize = 0;
    for (0..n) |i| {
        for (i + 1..n) |j| {
            total_phi += matrix[i][j];
            count += 1;
        }
    }
    const phi_coherence = if (count > 0) total_phi / @as(f64, @floatFromInt(count)) else 0;

    // Copy frequencies
    const freqs_copy = try allocator.alloc(f64, n);
    @memcpy(freqs_copy, freqs);

    return .{
        .frequencies = freqs_copy,
        .entanglement_matrix = matrix,
        .phi_coherence = phi_coherence,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED QUANTUM VISUALIZATION DATA
// ═══════════════════════════════════════════════════════════════════════════════

/// Visualization data for quantum states
pub const QuantumVizData = struct {
    state: QuantumState,
    bloch_angles: struct { theta: f64, phi: f64 },
    coherence_color: [3]f64, // RGB
    is_sacred: bool,
};

/// Generate visualization data for a quantum state
pub fn vizDataForState(state: QuantumState) QuantumVizData {
    const theta = 2.0 * std.math.acos(state.amplitude_zero.magnitude());
    const phi_phase = state.amplitude_one.phase() - state.amplitude_zero.phase();

    // Color based on φ-harmonicity
    const is_sacred = state.isPhiHarmonic();
    const hue: f64 = if (is_sacred) 0.15 else 0.6; // Gold vs Blue
    const saturation: f64 = if (is_sacred) 1.0 else 0.7;
    const value: f64 = 0.9;

    return .{
        .state = state,
        .bloch_angles = .{ .theta = theta, .phi = phi_phase },
        .coherence_color = hsvToRgb(hue, saturation, value),
        .is_sacred = is_sacred,
    };
}

fn hsvToRgb(h: f64, s: f64, v: f64) [3]f64 {
    const c = v * s;
    const x = c * (1 - @abs(@rem(@divTrunc(h / 60.0, 1), 2) - 1));
    const m = v - c;

    var r: f64 = 0;
    var g: f64 = 0;
    var b: f64 = 0;

    if (h < 60) {
        r = c;
        g = x;
    } else if (h < 120) {
        r = x;
        g = c;
    } else if (h < 180) {
        g = c;
        b = x;
    } else if (h < 240) {
        g = x;
        b = c;
    } else if (h < 300) {
        r = x;
        b = c;
    } else {
        r = c;
        b = x;
    }

    return .{ r + m, g + m, b + m };
}

// ═══════════════════════════════════════════════════════════════════════════════
// CLI COMMANDS
// ═══════════════════════════════════════════════════════════════════════════════

/// Show all quantum constants
pub fn cmdQuantumConstants(_: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║            SACRED QUANTUM CONSTANTS                           ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("Fundamental Constants:\n", .{});
    tri_colors.printGreen("  ħ (h-bar)   = {e:.6} J·s\n", .{H_BAR});
    tri_colors.printGreen("  h (Planck)  = {e:.6} J·s\n", .{H});
    tri_colors.printGreen("  α (fine)    = 1/137.036 = {d:.6}\n", .{ALPHA});

    tri_colors.printCyan("\nSacred Quantum Constants:\n", .{});
    tri_colors.printGold("  φ (quantum)  = {d:.15}...\n", .{PHI_QUANTUM});
    tri_colors.printGold("  |φ⟩ amplitude = {d:.6}\n", .{PHI_AMPLITUDE});
    tri_colors.printGold("  τ_coherence  = {d:.6} ms (φ-based)\n", .{SACRED_COHERENCE * 1000});

    tri_colors.printWhite("\n", .{});
}

/// Show quantum states
pub fn cmdQuantumStates(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║              QUANTUM STATES v18.0                            ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    const states = [_]struct { name: []const u8, state: QuantumState }{
        .{ .name = "|0⟩ (Zero)", .state = QuantumState.zero() },
        .{ .name = "|1⟩ (One)", .state = QuantumState.one() },
        .{ .name = "|+⟩ (Plus)", .state = QuantumState.plus() },
        .{ .name = "|−⟩ (Minus)", .state = QuantumState.minus() },
        .{ .name = "|φ⟩ (Sacred φ)", .state = QuantumState.phiState() },
    };

    for (states) |s| {
        tri_colors.printCyan("{s}: ", .{s.name});
        const alpha_str = try s.state.amplitude_zero.format(allocator);
        defer allocator.free(alpha_str);
        const beta_str = try s.state.amplitude_one.format(allocator);
        defer allocator.free(beta_str);
        tri_colors.printWhite("{s}|0⟩ + {s}|1⟩\n", .{ alpha_str, beta_str });
        tri_colors.printGray("    P(0) = {d:.1}%, P(1) = {d:.1}%, S = {d:.3} bits\n", .{
            s.state.probZero() * 100.0,
            s.state.probOne() * 100.0,
            s.state.entropy(),
        });
        if (s.state.isPhiHarmonic()) {
            tri_colors.printGold("    ✓ φ-HARMONIC STATE\n", .{});
        }
        tri_colors.printWhite("\n", .{});
    }
}

/// Show Bell states
pub fn cmdBellStates(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║              BELL STATES (Entanglement)                    ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    inline for (std.meta.fields(BellState)) |field| {
        const state = @field(BellState, field.name);
        tri_colors.printCyan("{s} = {s}\n", .{ state.name(), state.formula() });
    }

    tri_colors.printWhite("\nMaximally entangled two-qubit states.\n", .{});
    tri_colors.printGray("Concurrence = 1.0 for all Bell states.\n\n", .{});
}

/// Calculate consciousness metrics
pub fn cmdConsciousness(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;
    if (args.len < 2) {
        tri_colors.printRed("Error: Missing frequency arguments\n", .{});
        tri_colors.printGray("Usage: tri quantum consciousness <frequency> <brain_wave>\n", .{});
        tri_colors.printGray("Example: tri quantum consciousness 528 10\n", .{});
        tri_colors.printGray("  (528 Hz Solfeggio MI + 10 Hz Alpha wave)\n\n", .{});
        return;
    }

    const freq = std.fmt.parseFloat(f64, args[0]) catch {
        tri_colors.printRed("Error: Invalid frequency '{s}'\n", .{args[0]});
        return;
    };
    const brain_wave = std.fmt.parseFloat(f64, args[1]) catch {
        tri_colors.printRed("Error: Invalid brain wave frequency '{s}'\n", .{args[1]});
        return;
    };

    const metrics = calculateConsciousness(freq, brain_wave);

    tri_colors.printGold("\n╔═ QUANTUM CONSCIOUSNESS ═\n\n", .{});
    tri_colors.printCyan("Input Frequency: {d:.2} Hz\n", .{freq});
    tri_colors.printCyan("Brain Wave: {d:.2} Hz\n", .{brain_wave});
    tri_colors.printCyan("Ratio: {d:.3} (φ = {d:.3})\n\n", .{ freq / brain_wave, PHI_QUANTUM });

    const coherence_pct = metrics.quantum_coherence * 100.0;
    const entanglement_pct = metrics.entanglement_degree * 100.0;
    const phi_res_pct = metrics.phi_resonance * 100.0;

    tri_colors.printGreen("Quantum Coherence: ", .{});
    if (metrics.quantum_coherence > 0.8) {
        tri_colors.printGold("{d:.1}%\n", .{coherence_pct});
    } else {
        tri_colors.printWhite("{d:.1}%\n", .{coherence_pct});
    }

    tri_colors.printGreen("Entanglement Degree: ", .{});
    if (metrics.entanglement_degree > 0.7) {
        tri_colors.printGold("{d:.1}%\n", .{entanglement_pct});
    } else {
        tri_colors.printWhite("{d:.1}%\n", .{entanglement_pct});
    }

    tri_colors.printGreen("φ-Resonance: ", .{});
    if (metrics.phi_resonance > 0.7) {
        tri_colors.printGold("{d:.1}%\n", .{phi_res_pct});
    } else {
        tri_colors.printWhite("{d:.1}%\n", .{phi_res_pct});
    }

    tri_colors.printCyan("\nState: ", .{});
    if (metrics.sacred_state) {
        tri_colors.printGold("✓ SACRED CONSCIOUSNESS STATE\n", .{});
        tri_colors.printGold("\nThe quantum state is φ-harmonic!\n", .{});
    } else {
        tri_colors.printWhite("Ordinary\n", .{});
    }

    tri_colors.printWhite("\n", .{});
}

/// Calculate quantum music resonance
pub fn cmdQuantumMusic(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        tri_colors.printRed("Error: Need at least 2 frequencies\n", .{});
        tri_colors.printGray("Usage: tri quantum music <freq1> <freq2> [freq3...]\n", .{});
        tri_colors.printGray("Example: tri quantum music 396 417 528 639 741 852\n", .{});
        return;
    }

    var frequencies = std.ArrayList(f64).initCapacity(allocator, args.len) catch return;
    defer frequencies.deinit(allocator);

    for (args) |arg| {
        const freq = std.fmt.parseFloat(f64, arg) catch continue;
        try frequencies.append(allocator, freq);
    }

    if (frequencies.items.len < 2) {
        tri_colors.printRed("Error: At least 2 valid frequencies required\n", .{});
        return;
    }

    var harmony = try quantumMusicResonance(frequencies.items, allocator);
    defer harmony.deinit(allocator);

    tri_colors.printGold("\n╔═ QUANTUM MUSIC RESONANCE ═\n\n", .{});

    for (frequencies.items, 0..) |freq, i| {
        tri_colors.printGreen("{d}. {d:.2} Hz\n", .{ i + 1, freq });
    }

    tri_colors.printCyan("\nEntanglement Matrix:\n", .{});
    for (0..frequencies.items.len) |i| {
        for (0..frequencies.items.len) |j| {
            const val = harmony.entanglement_matrix[i][j];
            if (val > 0.9) {
                tri_colors.printGold("{d:.2} ", .{val});
            } else if (val > 0.7) {
                tri_colors.printCyan("{d:.2} ", .{val});
            } else {
                tri_colors.printGray("{d:.2} ", .{val});
            }
        }
        tri_colors.printWhite("\n", .{});
    }

    tri_colors.printCyan("\nφ-Coherence: ", .{});
    if (harmony.phi_coherence > 0.8) {
        tri_colors.printGold("{d:.1}%\n", .{harmony.phi_coherence * 100.0});
        tri_colors.printGold("\n✓ SACRED HARMONIC RESONANCE\n", .{});
    } else {
        tri_colors.printWhite("{d:.1}%\n", .{harmony.phi_coherence * 100.0});
    }

    tri_colors.printWhite("\n", .{});
}

/// Generate quantum visualization data
pub fn cmdQuantumViz(allocator: std.mem.Allocator, args: []const []const u8) !void {
    _ = allocator;

    const state = if (args.len > 0) blk: {
        if (std.mem.eql(u8, args[0], "phi")) {
            break :blk QuantumState.phiState();
        } else if (std.mem.eql(u8, args[0], "plus")) {
            break :blk QuantumState.plus();
        } else if (std.mem.eql(u8, args[0], "minus")) {
            break :blk QuantumState.minus();
        } else {
            break :blk QuantumState.plus();
        }
    } else QuantumState.phiState();

    const viz = vizDataForState(state);

    tri_colors.printGold("\n╔═ QUANTUM VISUALIZATION DATA ═\n\n", .{});

    tri_colors.printCyan("State: ", .{});
    if (viz.is_sacred) {
        tri_colors.printGold("SACRED |φ⟩ STATE\n\n", .{});
    } else {
        tri_colors.printWhite("Superposition\n\n", .{});
    }

    tri_colors.printCyan("Bloch Sphere Angles:\n", .{});
    tri_colors.printWhite("  θ (theta) = {d:.2}°\n", .{viz.bloch_angles.theta * 180.0 / std.math.pi});
    tri_colors.printWhite("  φ (phi)    = {d:.2}°\n", .{viz.bloch_angles.phi * 180.0 / std.math.pi});

    tri_colors.printCyan("\nProbabilities:\n", .{});
    tri_colors.printWhite("  P(|0⟩) = {d:.1}%\n", .{state.probZero() * 100.0});
    tri_colors.printWhite("  P(|1⟩) = {d:.1}%\n", .{state.probOne() * 100.0});

    tri_colors.printCyan("\nEntropy: {d:.3} bits\n", .{state.entropy()});

    tri_colors.printCyan("\nVisualization Color (RGB): ", .{});
    if (viz.is_sacred) {
        tri_colors.printGold("[{d:.2}, {d:.2}, {d:.2}] (Golden)\n", .{
            viz.coherence_color[0], viz.coherence_color[1], viz.coherence_color[2],
        });
    } else {
        tri_colors.printWhite("[{d:.2}, {d:.2}, {d:.2}]\n", .{
            viz.coherence_color[0], viz.coherence_color[1], viz.coherence_color[2],
        });
    }

    tri_colors.printWhite("\n", .{});
}

/// Show quantum help
pub fn cmdQuantumHelp(_: std.mem.Allocator, args: []const []const u8) !void {
    _ = args;

    tri_colors.printGold("\n╔══════════════════════════════════════════════════════════════╗\n", .{});
    tri_colors.printGold("║              SACRED QUANTUM v18.0                            ║\n", .{});
    tri_colors.printGold("╚══════════════════════════════════════════════════════════════╝\n\n", .{});

    tri_colors.printCyan("Commands:\n", .{});
    tri_colors.printGreen("  tri quantum constants          — Show sacred quantum constants\n", .{});
    tri_colors.printGreen("  tri quantum states             — Show all quantum states\n", .{});
    tri_colors.printGreen("  tri quantum bell               — Show Bell states (entanglement)\n", .{});
    tri_colors.printGreen("  tri quantum consciousness <f> <bw> — Calculate consciousness metrics\n", .{});
    tri_colors.printGreen("  tri quantum music <freqs>...    — Quantum music resonance\n", .{});
    tri_colors.printGreen("  tri quantum viz [state]         — Visualization data (phi/plus/minus)\n", .{});
    tri_colors.printGreen("  tri quantum help                — This help message\n", .{});

    tri_colors.printCyan("\nExamples:\n", .{});
    tri_colors.printWhite("  tri quantum consciousness 528 10\n", .{});
    tri_colors.printWhite("  tri quantum music 396 528 852\n", .{});
    tri_colors.printWhite("  tri quantum viz phi\n", .{});

    tri_colors.printWhite("\n", .{});
}
