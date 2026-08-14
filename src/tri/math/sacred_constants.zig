// ═══════════════════════════════════════════════════════════════════════════════
// TRI-MATH — Sacred Constants
// ═══════════════════════════════════════════════════════════════════════════════
//! Migrated from trinity-training/src/hslm/constants.zig
//!
//! φ² + 1/φ² = 3 = TRINITY
//!
//! All sacred mathematical constants for Trinity's AI architecture

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICAL CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Golden ratio φ = (1 + √5) / 2 ≈ 1.6180339887498948482
pub const PHI: f64 = 1.6180339887498948482;

/// 1/φ = φ - 1 ≈ 0.6180339887498948482
pub const PHI_INV: f64 = 0.6180339887498948482;

/// φ² = φ + 1 ≈ 2.6180339887498948482
pub const PHI_SQ: f64 = PHI * PHI;

/// φ⁻² ≈ 0.3819660112501051518
pub const PHI_INV_SQ: f64 = PHI_INV * PHI_INV;

/// φ³ = 2φ + 1 ≈ 4.2360679774997896964
pub const PHI_CUBED: f64 = PHI * PHI * PHI;

/// φ⁻³ ≈ 0.2360679774997896964
pub const PHI_INV_CUBED: f64 = 1.0 / (PHI * PHI * PHI);

/// √5 ≈ 2.2360679774997896964
pub const SQRT5: f64 = 2.2360679774997896964;

/// Trinity Identity: φ² + 1/φ² = 3 (exactly)
pub const TRINITY: f64 = 3.0;

/// Circle constant π ≈ 3.141592653589793
pub const PI: f64 = 3.1415926535897932385;

/// Euler's number e ≈ 2.718281828459045
pub const E: f64 = 2.7182818284590452354;

/// τ = 2π ≈ 6.283185307179586
pub const TAU: f64 = 2.0 * PI;

/// √2 ≈ 1.4142135623730951
pub const SQRT2: f64 = 1.4142135623730950488;

/// √3 ≈ 1.7320508075688772
pub const SQRT3: f64 = 1.7320508075688772935;

/// log₂(3) ≈ 1.5849625007211562 — bits per trit
pub const LOG2_3: f64 = 1.5849625007211562;

/// log₃(2) ≈ 0.6309297535714574 — trits per bit
pub const LOG3_2: f64 = 0.6309297535714574;

/// μ = 1/φ²/10 = 0.0382 (intelligence gain per fix)
pub const MU: f64 = PHI_INV_SQ / 10.0;

/// χ = 1/φ/10 ≈ 0.0618 (crossover rate) — эволюционная константа из φ
pub const CHI: f64 = PHI_INV / 10.0;

/// σ = φ ≈ 1.618 (selection pressure) — эволюционная константа из φ
pub const SIGMA: f64 = PHI;

/// ε = 1/3 ≈ 0.333 (elitism ratio) — доля от золотого тождества φ²+φ⁻²=3
pub const EPSILON: f64 = 1.0 / 3.0;

/// Lucas number L(10) = 123 (Trinity checksum)
pub const LAMBDA_10: f64 = 123.0;

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED CONSTANTS FOR HSLM (Hybrid Symbolic Language Model)
// ═══════════════════════════════════════════════════════════════════════════════

/// Sacred gamma = φ⁻³ ≈ 0.236 — ternary attention scale exponent
pub const SACRED_GAMMA: f64 = PHI_INV_CUBED;

/// Consciousness threshold = φ⁻¹ ≈ 0.618 — System 2 activation gate
pub const CONSCIOUSNESS_THRESHOLD: f64 = PHI_INV;

/// Golden Identity: φ² + φ⁻² = 3
pub const GOLDEN_IDENTITY: f64 = 3.0;

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL DIMENSIONS (powers of 3)
// ═══════════════════════════════════════════════════════════════════════════════

/// Vocabulary size = 3⁶ = 729 — token vocabulary
pub const VOCAB_SIZE: usize = 729;

/// Embedding dimension = 3⁵ = 243 — TNN float embedding
pub const EMBED_DIM: usize = 243;

/// Hidden layer dimension = 3⁶ = 729 — TNN hidden layer
pub const HIDDEN_DIM: usize = 729;

/// VSA hypervector dimension = 1024
pub const VSA_DIM: usize = 1024;

/// Default number of Trinity blocks = 3
pub const DEFAULT_BLOCKS: usize = 3;

/// Maximum number of blocks = 9 = 3² (for Wave 8)
pub const MAX_BLOCKS: usize = 9;

/// Context length = 3⁴ = 81 — sequence length
pub const CONTEXT_LEN: usize = 81;

/// Number of attention heads = 3 — Trinity
pub const NUM_HEADS: usize = 3;

/// Dimension per head = 3⁴ = 81
pub const HEAD_DIM: usize = 81;

/// Verify: NUM_HEADS * HEAD_DIM = 243 = EMBED_DIM ✓

// ═══════════════════════════════════════════════════════════════════════════════
// DERIVED DIMENSIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Output dimension = VOCAB_SIZE
pub const OUTPUT_DIM: usize = VOCAB_SIZE;

/// Default batch size = 3² = 9
pub const BATCH_SIZE_DEFAULT: usize = 9;

/// Maximum sequence length = CONTEXT_LEN
pub const MAX_SEQ_LEN: usize = CONTEXT_LEN;

// ═══════════════════════════════════════════════════════════════════════════════
// TRAINING HYPERPARAMETERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Learning rate = 10⁻³
pub const LEARNING_RATE: f32 = 1e-3;

/// Adam β₁ = 0.9
pub const ADAM_BETA1: f32 = 0.9;

/// Adam β₂ = 0.999
pub const ADAM_BETA2: f32 = 0.999;

/// Adam ε = 10⁻⁸
pub const ADAM_EPSILON: f32 = 1e-8;

/// Weight decay = 0.01
pub const WEIGHT_DECAY: f32 = 0.01;

/// Gradient clipping threshold = 1.0
pub const GRAD_CLIP: f32 = 1.0;

// ═══════════════════════════════════════════════════════════════════════════════
// T-JEPA CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════

/// EMA decay start = 0.996
pub const JEPA_EMA_DECAY_START: f32 = 0.996;

/// EMA decay end = 1.0
pub const JEPA_EMA_DECAY_END: f32 = 1.0;

/// Mask ratio = 0.6
pub const JEPA_MASK_RATIO: f32 = 0.6;

/// Minimum span = 3 (ternary)
pub const JEPA_MIN_SPAN: usize = 3;

/// Maximum span = 9 = 3² (sacred)
pub const JEPA_MAX_SPAN: usize = 9;

/// Number of spans = 3 (trinity)
pub const JEPA_NUM_SPANS: usize = 3;

// ═══════════════════════════════════════════════════════════════════════════════
// STRUCTS
// ═══════════════════════════════════════════════════════════════════════════════

/// Model configuration struct
pub const Config = struct {
    vocab_size: usize = VOCAB_SIZE,
    embed_dim: usize = EMBED_DIM,
    hidden_dim: usize = HIDDEN_DIM,
    vsa_dim: usize = VSA_DIM,
    num_blocks: usize = DEFAULT_BLOCKS,
    context_len: usize = CONTEXT_LEN,
    learning_rate: f32 = LEARNING_RATE,
    consciousness_threshold: f64 = CONSCIOUSNESS_THRESHOLD,
    use_bsd_verify: bool = false,

    /// Calculate parameter count for this config
    pub fn paramCount(self: Config) usize {
        const tnn_per_block = self.embed_dim * self.hidden_dim * 2 + self.hidden_dim + self.embed_dim;
        const attn_per_block = self.embed_dim * self.embed_dim * 4 + self.embed_dim; // Q+K+V+O + rms_gamma
        const per_block = tnn_per_block + attn_per_block;
        const blocks_total = per_block * self.num_blocks;
        const embedding = self.vocab_size * self.embed_dim;
        return blocks_total + embedding;
    }

    /// Calculate memory size in KB (ternary: 1.58 bits per param)
    pub fn memorySizeKB(self: Config) usize {
        const bits = @as(u64, @intCast(self.paramCount())) * 158 / 100;
        return @intCast(bits / 8 / 1024);
    }
};

/// Estimated parameter count (with DEFAULT_BLOCKS=3)
pub const ESTIMATED_PARAMS: usize = 1_952_991;

/// Estimated memory size in KB (with DEFAULT_BLOCKS=3)
pub const ESTIMATED_SIZE_KB: usize = 390;

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Validate block count: must be power of 3 and ≤ MAX_BLOCKS
pub fn isValidBlockCount(n: usize) bool {
    if (n == 0 or n > MAX_BLOCKS) return false;
    // Check power of 3: 1, 3, 9
    var v = n;
    while (v > 1) {
        if (v % 3 != 0) return false;
        v /= 3;
    }
    return true;
}

/// Verify Trinity Identity: φ² + 1/φ² = 3
pub fn verifyTrinityIdentity() bool {
    const trinity = PHI_SQ + PHI_INV_SQ;
    return @abs(trinity - TRINITY) < 1e-14;
}

/// Calculate φⁿ
pub fn phiPower(n: i32) f64 {
    if (n >= 0) {
        return std.math.pow(f64, PHI, @as(f64, @floatFromInt(n)));
    } else {
        return std.math.pow(f64, PHI_INV, @as(f64, @floatFromInt(-n)));
    }
}

/// Calculate Lucas number L(n) = φⁿ + (-1/φ)ⁿ
pub fn lucas(n: u32) f64 {
    const n_f: f64 = @floatFromInt(n);
    const phi_n = std.math.pow(f64, PHI, n_f);
    const inv_phi_n = std.math.pow(f64, -PHI_INV, n_f);
    return phi_n + inv_phi_n;
}

/// Calculate Fibonacci number F(n) = (φⁿ - (-1/φ)ⁿ) / √5
pub fn fibonacci(n: u32) f64 {
    const n_f: f64 = @floatFromInt(n);
    const phi_n = std.math.pow(f64, PHI, n_f);
    const inv_phi_n = std.math.pow(f64, -PHI_INV, n_f);
    return (phi_n - inv_phi_n) / SQRT5;
}

/// Sacred formula: V = n × 3^k × π^m × φ^p × e^q
pub fn sacredFormula(n: f64, k: f64, m: f64, p: f64, q: f64) f64 {
    return n * std.math.pow(f64, 3.0, k) *
        std.math.pow(f64, PI, m) *
        std.math.pow(f64, PHI, p) *
        std.math.pow(f64, E, q);
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "Trinity Identity: φ² + 1/φ² = 3" {
    try std.testing.expect(verifyTrinityIdentity());
    const trinity = PHI_SQ + PHI_INV_SQ;
    try std.testing.expectApproxEqAbs(TRINITY, trinity, 1e-10);
}

test "dimensions are powers of 3" {
    try std.testing.expect(VOCAB_SIZE == 729); // 3^6
    try std.testing.expect(EMBED_DIM == 243); // 3^5
    try std.testing.expect(HIDDEN_DIM == 729); // 3^6
    try std.testing.expect(CONTEXT_LEN == 81); // 3^4
    try std.testing.expect(HEAD_DIM == 81); // 3^4
}

test "NUM_HEADS * HEAD_DIM = EMBED_DIM" {
    try std.testing.expectEqual(EMBED_DIM, NUM_HEADS * HEAD_DIM);
}

test "valid block counts" {
    try std.testing.expect(isValidBlockCount(1));
    try std.testing.expect(isValidBlockCount(3));
    try std.testing.expect(isValidBlockCount(9));
    try std.testing.expect(!isValidBlockCount(0));
    try std.testing.expect(!isValidBlockCount(2));
    try std.testing.expect(!isValidBlockCount(6));
    try std.testing.expect(!isValidBlockCount(27)); // > MAX_BLOCKS=9
}

test "consciousness threshold is phi inverse" {
    try std.testing.expectApproxEqAbs(PHI_INV, CONSCIOUSNESS_THRESHOLD, 1e-10);
    try std.testing.expect(CONSCIOUSNESS_THRESHOLD > 0.6);
    try std.testing.expect(CONSCIOUSNESS_THRESHOLD < 0.62);
}

test "sacred gamma is phi inverse cubed" {
    try std.testing.expectApproxEqAbs(PHI_INV_CUBED, SACRED_GAMMA, 1e-14);
}

test "phi power" {
    try std.testing.expectApproxEqAbs(PHI, phiPower(1), 1e-14);
    try std.testing.expectApproxEqAbs(PHI_SQ, phiPower(2), 1e-14);
    try std.testing.expectApproxEqAbs(PHI_CUBED, phiPower(3), 1e-14);
    try std.testing.expectApproxEqAbs(PHI_INV, phiPower(-1), 1e-14);
}

test "Lucas numbers" {
    try std.testing.expectApproxEqAbs(@as(f64, 2), lucas(0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 1), lucas(1), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 3), lucas(2), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 4), lucas(3), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 123), lucas(10), 1e-10);
}

test "Fibonacci numbers" {
    try std.testing.expectApproxEqAbs(@as(f64, 0), fibonacci(0), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 1), fibonacci(1), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 1), fibonacci(2), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 2), fibonacci(3), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 3), fibonacci(4), 1e-10);
    try std.testing.expectApproxEqAbs(@as(f64, 55), fibonacci(10), 1e-10);
}

test "sacred formula with n=1, k=1, others=0" {
    const result = sacredFormula(1, 1, 0, 0, 0);
    try std.testing.expectApproxEqAbs(3.0, result, 0.0001);
}

test "config param count" {
    const cfg = Config{};
    const count = cfg.paramCount();
    // Should be roughly 1.95M (with sacred attention)
    try std.testing.expect(count > 1_900_000);
    try std.testing.expect(count < 2_100_000);
}

test "config memory size" {
    const cfg = Config{};
    const size_kb = cfg.memorySizeKB();
    // Should be roughly 390 KB
    try std.testing.expect(size_kb > 350);
    try std.testing.expect(size_kb < 450);
}
