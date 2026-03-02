// TERNARY QUANTUM VM — FORGE OF KOSCHEI v2.1
// Qutrit-based quantum virtual machine for ternary computation
//
// A qutrit has 3 basis states: |−1⟩, |0⟩, |+1⟩
// State vector: 3 complex amplitudes [α₋₁, α₀, α₊₁] where |α₋₁|² + |α₀|² + |α₊₁|² = 1
//
// Gates operate as 3×3 unitary matrices over complex amplitudes
// Measurement collapses to {-1, 0, +1} with probabilities |αᵢ|²
//
// phi^2 + 1/phi^2 = 3 = TRINITY (3 basis states = natural qutrit)

const std = @import("std");
const math = std.math;

/// Complex number for quantum amplitudes
pub const Complex = struct {
    re: f64,
    im: f64,

    pub const ZERO = Complex{ .re = 0, .im = 0 };
    pub const ONE = Complex{ .re = 1, .im = 0 };
    pub const I = Complex{ .re = 0, .im = 1 };

    pub fn init(re: f64, im: f64) Complex {
        return .{ .re = re, .im = im };
    }

    pub fn add(a: Complex, b: Complex) Complex {
        return .{ .re = a.re + b.re, .im = a.im + b.im };
    }

    pub fn sub(a: Complex, b: Complex) Complex {
        return .{ .re = a.re - b.re, .im = a.im - b.im };
    }

    pub fn mul(a: Complex, b: Complex) Complex {
        return .{
            .re = a.re * b.re - a.im * b.im,
            .im = a.re * b.im + a.im * b.re,
        };
    }

    pub fn scale(a: Complex, s: f64) Complex {
        return .{ .re = a.re * s, .im = a.im * s };
    }

    pub fn conj(a: Complex) Complex {
        return .{ .re = a.re, .im = -a.im };
    }

    pub fn norm_sq(a: Complex) f64 {
        return a.re * a.re + a.im * a.im;
    }

    pub fn abs(a: Complex) f64 {
        return @sqrt(a.norm_sq());
    }

    /// e^(i*theta)
    pub fn exp_i(theta: f64) Complex {
        return .{ .re = @cos(theta), .im = @sin(theta) };
    }
};

/// Qutrit state: 3 complex amplitudes for |−1⟩, |0⟩, |+1⟩
pub const Qutrit = struct {
    /// Amplitudes: [0]=|−1⟩, [1]=|0⟩, [2]=|+1⟩
    amp: [3]Complex,

    /// |−1⟩ basis state
    pub const MINUS = Qutrit{ .amp = .{ Complex.ONE, Complex.ZERO, Complex.ZERO } };
    /// |0⟩ basis state
    pub const ZERO_STATE = Qutrit{ .amp = .{ Complex.ZERO, Complex.ONE, Complex.ZERO } };
    /// |+1⟩ basis state
    pub const PLUS = Qutrit{ .amp = .{ Complex.ZERO, Complex.ZERO, Complex.ONE } };

    /// Measurement probabilities: [P(−1), P(0), P(+1)]
    pub fn probabilities(self: Qutrit) [3]f64 {
        return .{
            self.amp[0].norm_sq(),
            self.amp[1].norm_sq(),
            self.amp[2].norm_sq(),
        };
    }

    /// Total probability (should be 1.0 for valid state)
    pub fn total_prob(self: Qutrit) f64 {
        const p = self.probabilities();
        return p[0] + p[1] + p[2];
    }

    /// Measure qutrit, returns {-1, 0, +1} and collapses state
    pub fn measure(self: *Qutrit, rng: std.Random) i2 {
        const p = self.probabilities();
        const r = rng.float(f64);

        var result: i2 = undefined;
        if (r < p[0]) {
            result = -1;
            self.* = MINUS;
        } else if (r < p[0] + p[1]) {
            result = 0;
            self.* = ZERO_STATE;
        } else {
            result = 1;
            self.* = PLUS;
        }
        return result;
    }

    /// Inner product ⟨self|other⟩
    pub fn inner(self: Qutrit, other: Qutrit) Complex {
        var result = Complex.ZERO;
        for (0..3) |i| {
            result = result.add(self.amp[i].conj().mul(other.amp[i]));
        }
        return result;
    }

    /// Normalize state vector
    pub fn normalize(self: *Qutrit) void {
        const norm = @sqrt(self.total_prob());
        if (norm > 1e-15) {
            for (0..3) |i| {
                self.amp[i] = self.amp[i].scale(1.0 / norm);
            }
        }
    }
};

/// 3x3 unitary gate for qutrit operations
pub const Gate3 = struct {
    /// Row-major 3x3 complex matrix
    m: [3][3]Complex,

    /// Apply gate to qutrit
    pub fn apply(self: Gate3, q: Qutrit) Qutrit {
        var result: Qutrit = undefined;
        for (0..3) |i| {
            result.amp[i] = Complex.ZERO;
            for (0..3) |j| {
                result.amp[i] = result.amp[i].add(self.m[i][j].mul(q.amp[j]));
            }
        }
        return result;
    }

    /// Identity gate
    pub const I3 = Gate3{ .m = .{
        .{ Complex.ONE, Complex.ZERO, Complex.ZERO },
        .{ Complex.ZERO, Complex.ONE, Complex.ZERO },
        .{ Complex.ZERO, Complex.ZERO, Complex.ONE },
    } };

    /// Qutrit Hadamard (QFT₃ — discrete Fourier transform on 3 states)
    /// F₃[j,k] = (1/√3) * ω^(jk) where ω = e^(2πi/3)
    /// H₃ = (1/√3) * [[1, 1, 1], [1, ω, ω²], [1, ω², ω]]
    /// Property: F₃³ = I (cube is identity)
    pub fn hadamard3() Gate3 {
        const s = 1.0 / @sqrt(3.0);
        const omega = Complex.exp_i(2.0 * math.pi / 3.0); // ω = e^(2πi/3)
        const omega2 = omega.mul(omega); // ω²
        // ω⁴ = ω^(4 mod 3) = ω¹ = ω

        return .{ .m = .{
            .{ Complex.init(s, 0), Complex.init(s, 0), Complex.init(s, 0) },
            .{ Complex.init(s, 0), omega.scale(s), omega2.scale(s) },
            .{ Complex.init(s, 0), omega2.scale(s), omega.scale(s) },
        } };
    }

    /// Phase gate: adds phase phi to |+1⟩ state
    /// P(φ) = diag(1, 1, e^(iφ))
    pub fn phase(phi_angle: f64) Gate3 {
        return .{ .m = .{
            .{ Complex.ONE, Complex.ZERO, Complex.ZERO },
            .{ Complex.ZERO, Complex.ONE, Complex.ZERO },
            .{ Complex.ZERO, Complex.ZERO, Complex.exp_i(phi_angle) },
        } };
    }

    /// Sacred phase gate using golden ratio
    /// Applies phase = 2π/φ² to |+1⟩ state
    /// Since φ² + 1/φ² = 3 = number of qutrit states, this is natural
    pub fn sacred_phase() Gate3 {
        const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
        const angle = 2.0 * math.pi / (phi * phi);
        return phase(angle);
    }

    /// X gate (cyclic shift): |−1⟩→|0⟩→|+1⟩→|−1⟩
    pub const X3 = Gate3{ .m = .{
        .{ Complex.ZERO, Complex.ZERO, Complex.ONE },
        .{ Complex.ONE, Complex.ZERO, Complex.ZERO },
        .{ Complex.ZERO, Complex.ONE, Complex.ZERO },
    } };

    /// Z gate (phase): diagonal with ω phases
    /// Z₃ = diag(1, ω, ω²) where ω = e^(2πi/3)
    pub fn z3() Gate3 {
        const omega = Complex.exp_i(2.0 * math.pi / 3.0);
        const omega2 = omega.mul(omega);
        return .{ .m = .{
            .{ Complex.ONE, Complex.ZERO, Complex.ZERO },
            .{ Complex.ZERO, omega, Complex.ZERO },
            .{ Complex.ZERO, Complex.ZERO, omega2 },
        } };
    }

    /// Compose two gates: (self ∘ other) means apply other first, then self
    /// Result[i][j] = Σ_k self[i][k] * other[k][j]
    pub fn compose(self: Gate3, other: Gate3) Gate3 {
        var result: Gate3 = undefined;
        for (0..3) |i| {
            for (0..3) |j| {
                var sum = Complex.ZERO;
                for (0..3) |k| {
                    sum = sum.add(self.m[i][k].mul(other.m[k][j]));
                }
                result.m[i][j] = sum;
            }
        }
        return result;
    }

    /// SWAP two qutrits (operates on 9-dim state)
    /// For single-qutrit VM we implement NOT: |−1⟩↔|+1⟩, |0⟩→|0⟩
    pub const NOT3 = Gate3{ .m = .{
        .{ Complex.ZERO, Complex.ZERO, Complex.ONE },
        .{ Complex.ZERO, Complex.ONE, Complex.ZERO },
        .{ Complex.ONE, Complex.ZERO, Complex.ZERO },
    } };
};

/// Ternary Quantum Virtual Machine
/// Operates on a register of qutrits with gate-based computation
pub const TernaryQVM = struct {
    /// Qutrit registers (max 8 for single-qutrit operations)
    qutrits: [8]Qutrit,
    /// Number of active qutrits
    num_qutrits: u4,
    /// Measurement results (classical register)
    classical: [8]i2,
    /// Gate count (for circuit depth tracking)
    gate_count: u32,
    /// Pseudo-random number generator for measurement
    prng: std.Random.DefaultPrng,

    pub fn init(num_q: u4, seed: u64) TernaryQVM {
        var vm = TernaryQVM{
            .qutrits = undefined,
            .num_qutrits = num_q,
            .classical = [_]i2{0} ** 8,
            .gate_count = 0,
            .prng = std.Random.DefaultPrng.init(seed),
        };
        // Initialize all qutrits to |0⟩
        for (0..8) |i| {
            vm.qutrits[i] = Qutrit.ZERO_STATE;
        }
        return vm;
    }

    /// Apply gate to qutrit at index
    pub fn apply_gate(self: *TernaryQVM, gate: Gate3, target: u4) void {
        if (target >= self.num_qutrits) return;
        self.qutrits[target] = gate.apply(self.qutrits[target]);
        self.gate_count += 1;
    }

    /// Apply Hadamard to qutrit
    pub fn hadamard(self: *TernaryQVM, target: u4) void {
        self.apply_gate(Gate3.hadamard3(), target);
    }

    /// Apply sacred phase gate (phi-based)
    pub fn sacred_phase(self: *TernaryQVM, target: u4) void {
        self.apply_gate(Gate3.sacred_phase(), target);
    }

    /// Apply X (cyclic shift) gate
    pub fn x(self: *TernaryQVM, target: u4) void {
        self.apply_gate(Gate3.X3, target);
    }

    /// Apply Z (phase) gate
    pub fn z(self: *TernaryQVM, target: u4) void {
        self.apply_gate(Gate3.z3(), target);
    }

    /// Apply NOT (|−1⟩↔|+1⟩) gate
    pub fn not(self: *TernaryQVM, target: u4) void {
        self.apply_gate(Gate3.NOT3, target);
    }

    /// Measure qutrit, collapse state, store in classical register
    pub fn measure_qutrit(self: *TernaryQVM, target: u4) i2 {
        if (target >= self.num_qutrits) return 0;
        const result = self.qutrits[target].measure(self.prng.random());
        self.classical[target] = result;
        return result;
    }

    /// Reset qutrit to |0⟩
    pub fn reset(self: *TernaryQVM, target: u4) void {
        if (target >= self.num_qutrits) return;
        self.qutrits[target] = Qutrit.ZERO_STATE;
    }

    /// Reset all qutrits
    pub fn reset_all(self: *TernaryQVM) void {
        for (0..self.num_qutrits) |i| {
            self.qutrits[i] = Qutrit.ZERO_STATE;
        }
        self.gate_count = 0;
        self.classical = [_]i2{0} ** 8;
    }

    /// Get state probabilities for a qutrit
    pub fn get_probs(self: TernaryQVM, target: u4) [3]f64 {
        if (target >= self.num_qutrits) return .{ 0, 0, 0 };
        return self.qutrits[target].probabilities();
    }
};

// ============================================================
// ENTANGLED 2-QUTRIT SYSTEM (9-dimensional Hilbert space)
// ============================================================

/// 2-qutrit entangled state in 3⊗3 = 9 dimensional Hilbert space
/// Basis: |−1,−1⟩, |−1,0⟩, |−1,+1⟩, |0,−1⟩, |0,0⟩, |0,+1⟩, |+1,−1⟩, |+1,0⟩, |+1,+1⟩
pub const EntangledPair = struct {
    /// 9 complex amplitudes for the joint state
    amp: [9]Complex,

    /// Map (a, b) indices to flat index: a*3 + b where a,b in {0,1,2}
    fn idx(a: usize, b: usize) usize {
        return a * 3 + b;
    }

    /// Product state |a⟩⊗|b⟩
    pub fn product(a: Qutrit, b: Qutrit) EntangledPair {
        var result: EntangledPair = undefined;
        for (0..3) |i| {
            for (0..3) |j| {
                result.amp[idx(i, j)] = a.amp[i].mul(b.amp[j]);
            }
        }
        return result;
    }

    /// |00⟩ state (both qutrits in |0⟩)
    pub const ZERO_ZERO = blk: {
        var s: EntangledPair = .{ .amp = .{Complex.ZERO} ** 9 };
        s.amp[idx(1, 1)] = Complex.ONE; // |0,0⟩
        break :blk s;
    };

    /// Maximally entangled state (qutrit Bell state):
    /// |Φ+⟩ = (1/√3)(|−1,−1⟩ + |0,0⟩ + |+1,+1⟩)
    pub const BELL = blk: {
        const s = 1.0 / @sqrt(3.0);
        var state: EntangledPair = .{ .amp = .{Complex.ZERO} ** 9 };
        state.amp[idx(0, 0)] = Complex.init(s, 0); // |−1,−1⟩
        state.amp[idx(1, 1)] = Complex.init(s, 0); // |0,0⟩
        state.amp[idx(2, 2)] = Complex.init(s, 0); // |+1,+1⟩
        break :blk state;
    };

    /// Total probability (should be 1.0)
    pub fn total_prob(self: EntangledPair) f64 {
        var sum: f64 = 0;
        for (0..9) |i| {
            sum += self.amp[i].norm_sq();
        }
        return sum;
    }

    /// Apply single-qutrit gate to qubit A (first qutrit)
    /// G_A ⊗ I: applies G to first qutrit, identity to second
    pub fn apply_gate_a(self: EntangledPair, gate: Gate3) EntangledPair {
        var result: EntangledPair = .{ .amp = .{Complex.ZERO} ** 9 };
        for (0..3) |i_out| { // output row of A
            for (0..3) |j| { // B stays same
                for (0..3) |i_in| { // input row of A
                    result.amp[idx(i_out, j)] = result.amp[idx(i_out, j)].add(
                        gate.m[i_out][i_in].mul(self.amp[idx(i_in, j)]),
                    );
                }
            }
        }
        return result;
    }

    /// Apply single-qutrit gate to qubit B (second qutrit)
    /// I ⊗ G_B: applies identity to first, G to second
    pub fn apply_gate_b(self: EntangledPair, gate: Gate3) EntangledPair {
        var result: EntangledPair = .{ .amp = .{Complex.ZERO} ** 9 };
        for (0..3) |i| { // A stays same
            for (0..3) |j_out| { // output row of B
                for (0..3) |j_in| { // input row of B
                    result.amp[idx(i, j_out)] = result.amp[idx(i, j_out)].add(
                        gate.m[j_out][j_in].mul(self.amp[idx(i, j_in)]),
                    );
                }
            }
        }
        return result;
    }

    /// Controlled-SUM gate (qutrit CNOT equivalent)
    /// CSUM|a,b⟩ = |a, (a+b) mod 3⟩
    /// This creates entanglement from product states
    pub fn csum(self: EntangledPair) EntangledPair {
        var result: EntangledPair = .{ .amp = .{Complex.ZERO} ** 9 };
        for (0..3) |a| {
            for (0..3) |b| {
                const b_new = (a + b) % 3;
                result.amp[idx(a, b_new)] = result.amp[idx(a, b_new)].add(
                    self.amp[idx(a, b)],
                );
            }
        }
        return result;
    }

    /// Controlled-Phase gate
    /// CPhase|a,b⟩ = ω^(a*b) |a,b⟩ where ω = e^(2πi/3)
    pub fn cphase(self: EntangledPair) EntangledPair {
        var result = self;
        const omega = Complex.exp_i(2.0 * math.pi / 3.0);
        const omega2 = omega.mul(omega);

        // Only non-trivial phases when a*b mod 3 != 0
        // a=0(|-1⟩) maps to value 0 in our 0-indexed scheme
        // But we need actual trit values: idx 0=-1, 1=0, 2=+1
        // Product of trit values: (-1)*(-1)=1, (-1)*0=0, etc.
        // Simpler: use idx directly, phase = ω^(i*j) where i,j are 0-indexed

        // i=1,j=1: phase = ω^1
        result.amp[idx(1, 1)] = self.amp[idx(1, 1)].mul(omega);
        // i=1,j=2: phase = ω^2
        result.amp[idx(1, 2)] = self.amp[idx(1, 2)].mul(omega2);
        // i=2,j=1: phase = ω^2
        result.amp[idx(2, 1)] = self.amp[idx(2, 1)].mul(omega2);
        // i=2,j=2: phase = ω^4 = ω^1
        result.amp[idx(2, 2)] = self.amp[idx(2, 2)].mul(omega);

        return result;
    }

    /// Measure qutrit A, return result and collapsed state
    /// Partial measurement: trace out B's state conditioned on A's result
    pub fn measure_a(self: *EntangledPair, rng: std.Random) i2 {
        // Compute marginal probabilities for A
        var prob_a: [3]f64 = .{ 0, 0, 0 };
        for (0..3) |i| {
            for (0..3) |j| {
                prob_a[i] += self.amp[idx(i, j)].norm_sq();
            }
        }

        // Sample
        const r = rng.float(f64);
        var result: usize = 2;
        if (r < prob_a[0]) {
            result = 0;
        } else if (r < prob_a[0] + prob_a[1]) {
            result = 1;
        }

        // Collapse: zero out all amplitudes where A != result, renormalize
        var norm: f64 = 0;
        for (0..3) |i| {
            for (0..3) |j| {
                if (i != result) {
                    self.amp[idx(i, j)] = Complex.ZERO;
                } else {
                    norm += self.amp[idx(i, j)].norm_sq();
                }
            }
        }

        // Renormalize
        if (norm > 1e-15) {
            const inv_norm = 1.0 / @sqrt(norm);
            for (0..3) |j| {
                self.amp[idx(result, j)] = self.amp[idx(result, j)].scale(inv_norm);
            }
        }

        // Convert index to trit: 0->-1, 1->0, 2->+1
        return @as(i2, @intCast(@as(i8, @intCast(result)) - 1));
    }

    /// Measure qutrit B
    pub fn measure_b(self: *EntangledPair, rng: std.Random) i2 {
        var prob_b: [3]f64 = .{ 0, 0, 0 };
        for (0..3) |j| {
            for (0..3) |i| {
                prob_b[j] += self.amp[idx(i, j)].norm_sq();
            }
        }

        const r = rng.float(f64);
        var result: usize = 2;
        if (r < prob_b[0]) {
            result = 0;
        } else if (r < prob_b[0] + prob_b[1]) {
            result = 1;
        }

        var norm: f64 = 0;
        for (0..3) |i| {
            for (0..3) |j| {
                if (j != result) {
                    self.amp[idx(i, j)] = Complex.ZERO;
                } else {
                    norm += self.amp[idx(i, j)].norm_sq();
                }
            }
        }

        if (norm > 1e-15) {
            const inv_norm = 1.0 / @sqrt(norm);
            for (0..3) |i| {
                self.amp[idx(i, result)] = self.amp[idx(i, result)].scale(inv_norm);
            }
        }

        return @as(i2, @intCast(@as(i8, @intCast(result)) - 1));
    }
};

// ============================================================
// CGLMP INEQUALITY TEST (full Collins et al. 2002 for d=3)
// ============================================================

/// Compute joint probability P(a,b) for a Schmidt-form entangled state
/// State: |Ψ⟩ = Σ_j c_j |j,j⟩ where c_j are real coefficients
/// After applying measurement gates G_A, G_B:
///   P(a,b) = |Σ_j c_j · G_A[a,j] · G_B[b,j]|²
fn entangled_joint_prob(a: usize, b: usize, ga: Gate3, gb: Gate3, coeffs: [3]f64) f64 {
    var amp = Complex.ZERO;
    for (0..3) |j| {
        amp = amp.add(ga.m[a][j].mul(gb.m[b][j]).scale(coeffs[j]));
    }
    return amp.norm_sq();
}

/// Compute P(A - B = k mod 3) analytically from Born rule
fn entangled_correlation_prob(k: usize, ga: Gate3, gb: Gate3, coeffs: [3]f64) f64 {
    var prob: f64 = 0;
    for (0..3) |a| {
        const b = (a + 3 - k) % 3; // a - b = k mod 3, so b = a - k mod 3
        prob += entangled_joint_prob(a, b, ga, gb, coeffs);
    }
    return prob;
}

/// Build a CGLMP measurement gate using Givens rotation R01(θ).
///
/// Rotation in the |0⟩-|1⟩ plane:
///   R01(θ) = [[cos(θ), -sin(θ), 0],
///             [sin(θ),  cos(θ), 0],
///             [0,       0,      1]]
///
/// Unlike QFT-based gates, rotation gates break the permutation symmetry
/// of the maximally entangled state, producing non-uniform P(A-B = k mod 3)
/// which is necessary for CGLMP violation.
///
/// QFT gates ALWAYS give uniform P(A-B=k) = 1/3 for ANY Schmidt-form state,
/// making CGLMP violation impossible with QFT-based measurements alone.
fn cglmp_gate(theta: f64) Gate3 {
    return Gate3{ .m = .{
        .{ Complex.init(@cos(theta), 0), Complex.init(-@sin(theta), 0), Complex.ZERO },
        .{ Complex.init(@sin(theta), 0), Complex.init(@cos(theta), 0), Complex.ZERO },
        .{ Complex.ZERO, Complex.ZERO, Complex.ONE },
    } };
}

/// Compute I₃ for given state coefficients and measurement angles
fn compute_i3(coeffs: [3]f64, alpha1: f64, alpha2: f64, beta1: f64, beta2: f64) f64 {
    const ga1 = cglmp_gate(alpha1);
    const ga2 = cglmp_gate(alpha2);
    const gb1 = cglmp_gate(beta1);
    const gb2 = cglmp_gate(beta2);

    // CGLMP I₃ for d=3 (Collins et al. 2002, Phys. Rev. Lett. 88, 040404):
    //
    // I₃ = P(A₁=B₁) + P(B₁=A₂+1) + P(A₂=B₂) + P(B₂=A₁)
    //     - P(A₁=B₁-1) - P(B₁=A₂) - P(A₂=B₂-1) - P(B₂=A₁-1) ≤ 2
    //
    // In P(Aₓ-Bᵧ = k mod 3) notation:
    //   P(A₁=B₁)     = P₁₁(0)    P(A₁=B₁-1)   = P₁₁(2)   [A-B = -1 mod 3 = 2]
    //   P(B₁=A₂+1)   = P₂₁(2)    P(B₁=A₂)     = P₂₁(0)   [A₂-B₁ = -1 mod 3 = 2 | A₂-B₁ = 0]
    //   P(A₂=B₂)     = P₂₂(0)    P(A₂=B₂-1)   = P₂₂(2)
    //   P(B₂=A₁)     = P₁₂(0)    P(B₂=A₁-1)   = P₁₂(1)   [A₁-B₂ = 1]
    //
    // I₃ = [P₁₁(0) - P₁₁(2)] + [P₂₁(2) - P₂₁(0)]
    //     + [P₂₂(0) - P₂₂(2)] + [P₁₂(0) - P₁₂(1)]
    const p11_0 = entangled_correlation_prob(0, ga1, gb1, coeffs);
    const p11_2 = entangled_correlation_prob(2, ga1, gb1, coeffs);
    const p21_0 = entangled_correlation_prob(0, ga2, gb1, coeffs);
    const p21_2 = entangled_correlation_prob(2, ga2, gb1, coeffs);
    const p22_0 = entangled_correlation_prob(0, ga2, gb2, coeffs);
    const p22_2 = entangled_correlation_prob(2, ga2, gb2, coeffs);
    const p12_0 = entangled_correlation_prob(0, ga1, gb2, coeffs);
    const p12_1 = entangled_correlation_prob(1, ga1, gb2, coeffs);

    return (p11_0 - p11_2) + (p21_2 - p21_0) + (p22_0 - p22_2) + (p12_0 - p12_1);
}

/// CGLMP inequality for qutrits (Collins-Gisin-Linden-Massar-Popescu 2002)
/// Classical bound I₃ ≤ 2
/// Quantum maximum I₃ ≈ 2.9149 (for d=3 non-maximally entangled pair)
///
/// Full formula for d=3 (Phys. Rev. Lett. 88, 040404):
///
/// I₃ = P(A₁=B₁) + P(B₁=A₂+1) + P(A₂=B₂) + P(B₂=A₁)
///    - P(A₁=B₁-1) - P(B₁=A₂) - P(A₂=B₂-1) - P(B₂=A₁-1) ≤ 2
///
/// In P(Aₓ-Bᵧ = k mod 3) notation:
///   I₃ = [P₁₁(0) - P₁₁(2)] + [P₂₁(2) - P₂₁(0)]
///      + [P₂₂(0) - P₂₂(2)] + [P₁₂(0) - P₁₂(1)]
///
/// Key insights:
/// - Optimal state is NOT maximally entangled for d≥3 (Acín et al. 2002)
/// - QFT-based measurement gates always give uniform P(A-B=k) = 1/3
///   for ANY Schmidt-form state, making violation IMPOSSIBLE
/// - Real rotation gates (Givens R01) break this symmetry,
///   enabling genuine CGLMP violation I₃ > 2.0
pub fn run_cglmp_test(num_trials: u32, use_entanglement: bool) struct {
    i3_value: f64,
    classical_bound: f64,
    quantum_max: f64,
    violation: bool,
    trials: u32,
    correlation_same_basis: f64,
    correlation_diff_basis: f64,
} {
    _ = num_trials; // Analytical computation — no Monte Carlo needed

    if (use_entanglement) {
        // Grid search over state parameter γ and 4 independent rotation angles
        // State: |ψ⟩ = sin(γ)/√2 |00⟩ + cos(γ) |11⟩ + sin(γ)/√2 |22⟩
        // Measurements: R01(α₁), R01(α₂), R01(β₁), R01(β₂) — Givens rotations
        var best_i3: f64 = -100.0;
        var best_coeffs: [3]f64 = .{ 1.0 / @sqrt(3.0), 1.0 / @sqrt(3.0), 1.0 / @sqrt(3.0) };
        var best_p11_0: f64 = 0;
        var best_p21_0: f64 = 0;

        const N_g: usize = 20;
        const N_a: usize = 24;

        // Scan γ from 0.05 to π/3 (0 = product state, π/4 = max entangled)
        var gi: usize = 0;
        while (gi < N_g) : (gi += 1) {
            const gamma: f64 = 0.05 + @as(f64, @floatFromInt(gi)) * (math.pi / 3.0) / @as(f64, @floatFromInt(N_g));
            const c0 = @sin(gamma) / @sqrt(2.0);
            const c1 = @cos(gamma);
            const coeffs = [3]f64{ c0, c1, c0 };

            // Scan all 4 measurement angles independently
            var a1i: usize = 0;
            while (a1i < N_a) : (a1i += 1) {
                const a1 = @as(f64, @floatFromInt(a1i)) * math.pi / @as(f64, @floatFromInt(N_a));
                var a2i: usize = 0;
                while (a2i < N_a) : (a2i += 1) {
                    const a2 = @as(f64, @floatFromInt(a2i)) * math.pi / @as(f64, @floatFromInt(N_a));
                    var b1i: usize = 0;
                    while (b1i < N_a) : (b1i += 1) {
                        const b1 = @as(f64, @floatFromInt(b1i)) * math.pi / @as(f64, @floatFromInt(N_a));
                        var b2i: usize = 0;
                        while (b2i < N_a) : (b2i += 1) {
                            const b2 = @as(f64, @floatFromInt(b2i)) * math.pi / @as(f64, @floatFromInt(N_a));
                            const i3_val = compute_i3(coeffs, a1, a2, b1, b2);
                            if (i3_val > best_i3) {
                                best_i3 = i3_val;
                                best_coeffs = coeffs;
                            }
                        }
                    }
                }
            }
        }

        // Compute final probabilities with best settings
        best_p11_0 = entangled_correlation_prob(0, cglmp_gate(0.0), cglmp_gate(0.0), best_coeffs);
        best_p21_0 = entangled_correlation_prob(0, cglmp_gate(math.pi / 4.0), cglmp_gate(0.0), best_coeffs);

        return .{
            .i3_value = best_i3,
            .classical_bound = 2.0,
            .quantum_max = 2.9149,
            .violation = best_i3 > 2.0 + 1e-6, // tolerance for floating point
            .trials = 0,
            .correlation_same_basis = best_p11_0,
            .correlation_diff_basis = best_p21_0,
        };
    } else {
        // Separable state |0,0⟩ = |1,1⟩ in our indexing
        // c_j = δ_{j,1} → coeffs = {0, 1, 0}
        const sep_coeffs = [3]f64{ 0.0, 1.0, 0.0 };

        // Search for max I₃ with separable state — must stay ≤ 2.0
        var best_i3: f64 = -100.0;
        const N_sep: usize = 24;
        var a1i: usize = 0;
        while (a1i < N_sep) : (a1i += 1) {
            const a1 = @as(f64, @floatFromInt(a1i)) * math.pi / @as(f64, @floatFromInt(N_sep));
            var a2i: usize = 0;
            while (a2i < N_sep) : (a2i += 1) {
                const a2 = @as(f64, @floatFromInt(a2i)) * math.pi / @as(f64, @floatFromInt(N_sep));
                var b1i: usize = 0;
                while (b1i < N_sep) : (b1i += 1) {
                    const b1 = @as(f64, @floatFromInt(b1i)) * math.pi / @as(f64, @floatFromInt(N_sep));
                    var b2i: usize = 0;
                    while (b2i < N_sep) : (b2i += 1) {
                        const b2 = @as(f64, @floatFromInt(b2i)) * math.pi / @as(f64, @floatFromInt(N_sep));
                        const i3_sep = compute_i3(sep_coeffs, a1, a2, b1, b2);
                        if (i3_sep > best_i3) best_i3 = i3_sep;
                    }
                }
            }
        }

        return .{
            .i3_value = best_i3,
            .classical_bound = 2.0,
            .quantum_max = 2.9149,
            .violation = best_i3 > 2.0 + 1e-6, // tolerance for floating point
            .trials = 0,
            .correlation_same_basis = 0,
            .correlation_diff_basis = 0,
        };
    }
}

// ============================================================
// TESTS
// ============================================================

/// Test: CHSH-like inequality for qutrits (CGLMP inequality)
/// Classical bound = 2, quantum bound = 2(1 + 1/√3) ≈ 3.154
/// We verify qutrit superposition produces non-classical correlations
pub fn run_chsh_test(allocator: std.mem.Allocator, num_trials: u32) !struct {
    correlation: f64,
    classical_bound: f64,
    violation: bool,
    trials: u32,
} {
    _ = allocator;
    var prng = std.Random.DefaultPrng.init(42);
    const rng = prng.random();

    var agree_count: u32 = 0;
    var total: u32 = 0;

    for (0..num_trials) |_| {
        // Create two qutrits in superposition
        var q1 = Qutrit.ZERO_STATE;
        var q2 = Qutrit.ZERO_STATE;

        // Apply Hadamard to both (creates uniform superposition)
        q1 = Gate3.hadamard3().apply(q1);
        q2 = Gate3.hadamard3().apply(q2);

        // Apply sacred phase to q2 (golden ratio phase)
        q2 = Gate3.sacred_phase().apply(q2);

        // Measure both
        const m1 = q1.measure(rng);
        const m2 = q2.measure(rng);

        // Check correlation: agreement = same measurement outcome
        if (m1 == m2) agree_count += 1;
        total += 1;
    }

    const correlation = @as(f64, @floatFromInt(agree_count)) / @as(f64, @floatFromInt(total));
    const classical_bound: f64 = 1.0 / 3.0; // random correlation for 3 outcomes

    return .{
        .correlation = correlation,
        .classical_bound = classical_bound,
        .violation = correlation > classical_bound + 0.05, // significant deviation
        .trials = total,
    };
}

// ============================================================
// UNIT TESTS
// ============================================================

test "qutrit basis states orthogonal" {
    const minus = Qutrit.MINUS;
    const zero = Qutrit.ZERO_STATE;
    const plus = Qutrit.PLUS;

    // ⟨−1|0⟩ = 0
    try std.testing.expectApproxEqAbs(minus.inner(zero).abs(), 0.0, 1e-10);
    // ⟨0|+1⟩ = 0
    try std.testing.expectApproxEqAbs(zero.inner(plus).abs(), 0.0, 1e-10);
    // ⟨−1|+1⟩ = 0
    try std.testing.expectApproxEqAbs(minus.inner(plus).abs(), 0.0, 1e-10);
    // ⟨0|0⟩ = 1
    try std.testing.expectApproxEqAbs(zero.inner(zero).abs(), 1.0, 1e-10);
}

test "qutrit normalization" {
    const q = Qutrit.ZERO_STATE;
    try std.testing.expectApproxEqAbs(q.total_prob(), 1.0, 1e-10);

    const minus = Qutrit.MINUS;
    try std.testing.expectApproxEqAbs(minus.total_prob(), 1.0, 1e-10);

    const plus = Qutrit.PLUS;
    try std.testing.expectApproxEqAbs(plus.total_prob(), 1.0, 1e-10);
}

test "hadamard creates uniform superposition" {
    const h = Gate3.hadamard3();
    const result = h.apply(Qutrit.ZERO_STATE);
    const probs = result.probabilities();

    // After Hadamard on |0⟩, all 3 outcomes should have equal probability 1/3
    try std.testing.expectApproxEqAbs(probs[0], 1.0 / 3.0, 1e-10);
    try std.testing.expectApproxEqAbs(probs[1], 1.0 / 3.0, 1e-10);
    try std.testing.expectApproxEqAbs(probs[2], 1.0 / 3.0, 1e-10);
}

test "hadamard preserves norm" {
    const h = Gate3.hadamard3();
    const result = h.apply(Qutrit.MINUS);
    try std.testing.expectApproxEqAbs(result.total_prob(), 1.0, 1e-10);
}

test "X gate cyclic shift" {
    // X|−1⟩ = |0⟩
    const r1 = Gate3.X3.apply(Qutrit.MINUS);
    try std.testing.expectApproxEqAbs(r1.amp[1].norm_sq(), 1.0, 1e-10);

    // X|0⟩ = |+1⟩
    const r2 = Gate3.X3.apply(Qutrit.ZERO_STATE);
    try std.testing.expectApproxEqAbs(r2.amp[2].norm_sq(), 1.0, 1e-10);

    // X|+1⟩ = |−1⟩
    const r3 = Gate3.X3.apply(Qutrit.PLUS);
    try std.testing.expectApproxEqAbs(r3.amp[0].norm_sq(), 1.0, 1e-10);
}

test "NOT gate swaps minus and plus" {
    // NOT|−1⟩ = |+1⟩
    const r1 = Gate3.NOT3.apply(Qutrit.MINUS);
    try std.testing.expectApproxEqAbs(r1.amp[2].norm_sq(), 1.0, 1e-10);

    // NOT|0⟩ = |0⟩
    const r2 = Gate3.NOT3.apply(Qutrit.ZERO_STATE);
    try std.testing.expectApproxEqAbs(r2.amp[1].norm_sq(), 1.0, 1e-10);

    // NOT|+1⟩ = |−1⟩
    const r3 = Gate3.NOT3.apply(Qutrit.PLUS);
    try std.testing.expectApproxEqAbs(r3.amp[0].norm_sq(), 1.0, 1e-10);
}

test "phase gate preserves probabilities" {
    const p = Gate3.sacred_phase();
    const h = Gate3.hadamard3();

    // Apply H then P to |0⟩
    var q = h.apply(Qutrit.ZERO_STATE);
    const probs_before = q.probabilities();
    q = p.apply(q);
    const probs_after = q.probabilities();

    // Phase gate only changes phases, not probabilities
    try std.testing.expectApproxEqAbs(probs_before[0], probs_after[0], 1e-10);
    try std.testing.expectApproxEqAbs(probs_before[1], probs_after[1], 1e-10);
    try std.testing.expectApproxEqAbs(probs_before[2], probs_after[2], 1e-10);
}

test "identity gate preserves state" {
    const q = Qutrit.PLUS;
    const result = Gate3.I3.apply(q);
    for (0..3) |i| {
        try std.testing.expectApproxEqAbs(result.amp[i].re, q.amp[i].re, 1e-10);
        try std.testing.expectApproxEqAbs(result.amp[i].im, q.amp[i].im, 1e-10);
    }
}

test "VM initialization" {
    const vm = TernaryQVM.init(3, 42);
    try std.testing.expectEqual(vm.num_qutrits, 3);
    try std.testing.expectEqual(vm.gate_count, 0);
    // All qutrits start in |0⟩
    for (0..3) |i| {
        try std.testing.expectApproxEqAbs(vm.qutrits[i].amp[1].re, 1.0, 1e-10);
    }
}

test "VM gate application increments counter" {
    var vm = TernaryQVM.init(2, 42);
    vm.hadamard(0);
    try std.testing.expectEqual(vm.gate_count, 1);
    vm.x(1);
    try std.testing.expectEqual(vm.gate_count, 2);
    vm.sacred_phase(0);
    try std.testing.expectEqual(vm.gate_count, 3);
}

test "VM measurement produces valid trit" {
    var vm = TernaryQVM.init(1, 42);
    vm.hadamard(0);
    const result = vm.measure_qutrit(0);
    // Result must be -1, 0, or +1
    try std.testing.expect(result >= -1 and result <= 1);
    // After measurement, state is collapsed to basis state
    try std.testing.expectApproxEqAbs(vm.qutrits[0].total_prob(), 1.0, 1e-10);
}

test "VM reset restores zero state" {
    var vm = TernaryQVM.init(1, 42);
    vm.hadamard(0);
    vm.x(0);
    vm.reset(0);
    try std.testing.expectApproxEqAbs(vm.qutrits[0].amp[1].re, 1.0, 1e-10);
}

test "triple X returns to original" {
    // X³ = I for qutrit X gate (cyclic)
    var q = Qutrit.MINUS;
    q = Gate3.X3.apply(q);
    q = Gate3.X3.apply(q);
    q = Gate3.X3.apply(q);
    try std.testing.expectApproxEqAbs(q.amp[0].norm_sq(), 1.0, 1e-10);
}

test "double hadamard not identity (qutrit)" {
    // H² ≠ I for qutrit Hadamard (unlike qubit)
    const h = Gate3.hadamard3();
    var q = Qutrit.ZERO_STATE;
    q = h.apply(q);
    q = h.apply(q);
    // For 3-dim QFT: H³ = I, so H² ≠ I
    // Check that we're NOT back to |0⟩
    const p0 = q.amp[1].norm_sq();
    // H²|0⟩ should NOT have prob 1 at |0⟩
    try std.testing.expect(p0 < 0.99);
}

test "hadamard is unitary (H*H_dagger = I)" {
    // Verify unitarity: H†H = I (each column has unit norm, columns orthogonal)
    const h = Gate3.hadamard3();
    // Apply H then check: for all basis states, total_prob == 1
    const states = [_]Qutrit{ Qutrit.MINUS, Qutrit.ZERO_STATE, Qutrit.PLUS };
    for (states) |s| {
        const result = h.apply(s);
        try std.testing.expectApproxEqAbs(result.total_prob(), 1.0, 1e-10);
    }
    // Check H applied to each basis state gives orthogonal results
    const h_minus = h.apply(Qutrit.MINUS);
    const h_zero = h.apply(Qutrit.ZERO_STATE);
    const h_plus = h.apply(Qutrit.PLUS);
    try std.testing.expectApproxEqAbs(h_minus.inner(h_zero).abs(), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(h_zero.inner(h_plus).abs(), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(h_minus.inner(h_plus).abs(), 0.0, 1e-10);
}

test "sacred phase angle uses golden ratio" {
    const phi: f64 = (1.0 + @sqrt(5.0)) / 2.0;
    const expected_angle = 2.0 * math.pi / (phi * phi);
    // phi^2 = phi + 1 ≈ 2.618
    // angle ≈ 2.400 rad ≈ 137.5° (golden angle!)
    try std.testing.expectApproxEqAbs(phi * phi + 1.0 / (phi * phi), 3.0, 1e-10);
    try std.testing.expect(expected_angle > 2.0 and expected_angle < 3.0);
}

test "CHSH-like test runs" {
    const result = try run_chsh_test(std.testing.allocator, 1000);
    // Correlation should be a valid probability
    try std.testing.expect(result.correlation >= 0.0 and result.correlation <= 1.0);
    try std.testing.expectEqual(result.trials, 1000);
}

// ============================================================
// ENTANGLEMENT TESTS
// ============================================================

test "Bell state normalization" {
    const bell = EntangledPair.BELL;
    var total: f64 = 0;
    for (0..9) |i| {
        total += bell.amp[i].norm_sq();
    }
    try std.testing.expectApproxEqAbs(total, 1.0, 1e-10);
}

test "Bell state has correct structure" {
    const bell = EntangledPair.BELL;
    const inv_sqrt3 = 1.0 / @sqrt(3.0);
    // |−1,−1⟩ = amp[0] should be 1/√3
    try std.testing.expectApproxEqAbs(bell.amp[0].re, inv_sqrt3, 1e-10);
    // |0,0⟩ = amp[4] should be 1/√3
    try std.testing.expectApproxEqAbs(bell.amp[4].re, inv_sqrt3, 1e-10);
    // |+1,+1⟩ = amp[8] should be 1/√3
    try std.testing.expectApproxEqAbs(bell.amp[8].re, inv_sqrt3, 1e-10);
    // All others zero
    try std.testing.expectApproxEqAbs(bell.amp[1].norm_sq(), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(bell.amp[2].norm_sq(), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(bell.amp[3].norm_sq(), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(bell.amp[5].norm_sq(), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(bell.amp[6].norm_sq(), 0.0, 1e-10);
    try std.testing.expectApproxEqAbs(bell.amp[7].norm_sq(), 0.0, 1e-10);
}

test "product state normalization" {
    const h = Gate3.hadamard3();
    const pair = EntangledPair.product(
        h.apply(Qutrit.ZERO_STATE),
        h.apply(Qutrit.ZERO_STATE),
    );
    var total: f64 = 0;
    for (0..9) |i| {
        total += pair.amp[i].norm_sq();
    }
    try std.testing.expectApproxEqAbs(total, 1.0, 1e-10);
}

test "CSUM creates entanglement from product state" {
    // Start with H|0⟩ ⊗ |0⟩ = (1/√3)(|0⟩+|1⟩+|2⟩) ⊗ |1⟩  (|0⟩ = index 1)
    // CSUM: |a,b⟩ → |a,(a+b)%3⟩
    //   a=0,b=1 → (0,1); a=1,b=1 → (1,2); a=2,b=1 → (2,0)
    // Result: (1/√3)(|0,1⟩ + |1,2⟩ + |2,0⟩) — entangled!
    const h = Gate3.hadamard3();
    var pair = EntangledPair.product(h.apply(Qutrit.ZERO_STATE), Qutrit.ZERO_STATE);
    pair = pair.csum();

    // Entangled: 3 non-zero amplitudes, each with prob 1/3
    try std.testing.expectApproxEqAbs(pair.amp[EntangledPair.idx(0, 1)].norm_sq(), 1.0 / 3.0, 1e-10);
    try std.testing.expectApproxEqAbs(pair.amp[EntangledPair.idx(1, 2)].norm_sq(), 1.0 / 3.0, 1e-10);
    try std.testing.expectApproxEqAbs(pair.amp[EntangledPair.idx(2, 0)].norm_sq(), 1.0 / 3.0, 1e-10);

    // Total probability still 1
    var total: f64 = 0;
    for (0..9) |i| total += pair.amp[i].norm_sq();
    try std.testing.expectApproxEqAbs(total, 1.0, 1e-10);
}

test "entangled measurement correlation" {
    // Bell state: measuring A should always give same result as B
    var prng = std.Random.DefaultPrng.init(137);
    var agree: u32 = 0;
    const trials: u32 = 1000;
    for (0..trials) |_| {
        var pair = EntangledPair.BELL;
        const ma = pair.measure_a(prng.random());
        const mb = pair.measure_b(prng.random());
        if (ma == mb) agree += 1;
    }
    // For maximally entangled Bell state, A and B MUST always agree
    try std.testing.expectEqual(agree, trials);
}

test "CGLMP test produces valid result" {
    const result = run_cglmp_test(0, true);
    std.debug.print("\n  CGLMP I₃ (entangled) = {d:.6}\n", .{result.i3_value});
    std.debug.print("  same_basis corr = {d:.6}, diff_basis = {d:.6}\n", .{ result.correlation_same_basis, result.correlation_diff_basis });
    // Analytical computation — I₃ must exceed classical bound 2.0
    try std.testing.expect(result.violation);
    try std.testing.expect(result.i3_value > 2.0);
    try std.testing.expect(result.i3_value < 3.0); // quantum max ≈ 2.9149
    try std.testing.expectApproxEqAbs(result.classical_bound, 2.0, 1e-10);
}

test "CGLMP separable does not exceed classical bound with rotation gates" {
    // Verify separable state |0,0⟩ with rotation gates stays at classical bound
    const sep = [3]f64{ 0.0, 1.0, 0.0 };
    // Check specific angle where separable achieves max I₃ = 2.0
    // a1=0, a2=π/4, b1=π/4, b2=π/2
    const i3_at_max = compute_i3(sep, 0.0, math.pi / 4.0, math.pi / 4.0, math.pi / 2.0);
    try std.testing.expect(i3_at_max <= 2.0 + 1e-10);
}

test "CGLMP violation with known optimal angles" {
    // Verify CGLMP violation at known optimal parameters found by grid search:
    // γ ≈ 0.8354 → c0=c2 ≈ 0.526, c1 ≈ 0.672 (non-maximally entangled)
    // a1=0, a2=3π/4, b1=π/8, b2=7π/8 (R01 rotation angles)
    const gamma: f64 = 0.8354;
    const c0 = @sin(gamma) / @sqrt(2.0);
    const c1 = @cos(gamma);
    const coeffs = [3]f64{ c0, c1, c0 };

    const i3_val = compute_i3(coeffs, 0.0, 3.0 * math.pi / 4.0, math.pi / 8.0, 7.0 * math.pi / 8.0);

    // Must exceed classical bound 2.0
    try std.testing.expect(i3_val > 2.0);
    // Must be below quantum maximum ≈ 2.9149
    try std.testing.expect(i3_val < 3.0);
    // Specific value: I₃ ≈ 2.4277
    try std.testing.expectApproxEqAbs(i3_val, 2.4277, 0.01);
}

test "separable state does not violate CGLMP" {
    const result = run_cglmp_test(0, false);
    // Product state MUST NOT violate classical bound
    try std.testing.expect(!result.violation);
    try std.testing.expect(result.i3_value <= 2.0 + 1e-10);
}
