// @origin(spec:constants.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Hybrid Symbolic Language Model
// Sacred constants and configuration
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");

// ═══════════════════════════════════════════════════════════════════════════════
// SACRED MATHEMATICAL CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.6180339887498948482; // Golden ratio
pub const PHI_INV: f64 = 0.6180339887498948482; // 1/φ = φ - 1
pub const PHI_SQ: f64 = PHI * PHI; // φ² ≈ 2.618
pub const PHI_INV_SQ: f64 = PHI_INV * PHI_INV; // φ⁻² ≈ 0.382
pub const TRINITY_CONST: f64 = 3.0; // φ² + φ⁻² = 3
pub const CONSCIOUSNESS_THRESHOLD: f64 = PHI_INV; // 0.618 — System 2 activation gate
pub const LOG2_3: f64 = 1.5849625007211562; // log₂(3) — bits per trit
pub const PHI_INV_CUBED: f64 = 1.0 / (PHI * PHI * PHI); // φ⁻³ ≈ 0.2360679...
pub const SACRED_GAMMA: f64 = PHI_INV_CUBED; // Ternary attention scale exponent

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL DIMENSIONS (powers of 3)
// ═══════════════════════════════════════════════════════════════════════════════

pub const VOCAB_SIZE: usize = 729; // 3⁶ — token vocabulary
pub const EMBED_DIM: usize = 243; // 3⁵ — TNN float embedding
pub const HIDDEN_DIM: usize = 729; // 3⁶ — TNN hidden layer
pub const VSA_DIM: usize = 1024; // Hypervector space
pub const DEFAULT_BLOCKS: usize = 3; // Trinity blocks (default)
pub const NUM_BLOCKS: usize = DEFAULT_BLOCKS; // Alias for backward compat
pub const MAX_BLOCKS: usize = 9; // Max blocks for Wave 8 (3²)

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
pub const CONTEXT_LEN: usize = 81; // 3⁴ — sequence length
pub const NUM_HEADS: usize = 3; // Trinity — sacred attention heads
pub const HEAD_DIM: usize = 81; // 3⁴ — per-head dimension
// Verify: NUM_HEADS * HEAD_DIM = 243 = EMBED_DIM

// ═══════════════════════════════════════════════════════════════════════════════
// DERIVED DIMENSIONS
// ═══════════════════════════════════════════════════════════════════════════════

pub const OUTPUT_DIM: usize = VOCAB_SIZE; // Output projection targets vocab
pub const BATCH_SIZE_DEFAULT: usize = 9; // 3² — default batch size
pub const MAX_SEQ_LEN: usize = CONTEXT_LEN; // Alias

// ═══════════════════════════════════════════════════════════════════════════════
// TRAINING HYPERPARAMETERS
// ═══════════════════════════════════════════════════════════════════════════════

pub const LEARNING_RATE: f32 = 1e-3;
pub const ADAM_BETA1: f32 = 0.9;
pub const ADAM_BETA2: f32 = 0.999;
pub const ADAM_EPSILON: f32 = 1e-8;
pub const WEIGHT_DECAY: f32 = 0.01;
pub const GRAD_CLIP: f32 = 1.0;

// ═══════════════════════════════════════════════════════════════════════════════
// PARAMETER COUNT ESTIMATE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Per TrinityBlock:
//   TNN dense: EMBED_DIM × HIDDEN_DIM + HIDDEN_DIM × EMBED_DIM = 243×729 + 729×243 = 354,294
//   TNN biases: HIDDEN_DIM + EMBED_DIM = 729 + 243 = 972
//   Sacred Attention: 4 × EMBED_DIM² + EMBED_DIM = 4×59049 + 243 = 236,439
//   Subtotal per block: ~591,705
//
// 3 blocks: 591,705 × 3 = 1,775,115
//
// Embeddings: VOCAB_SIZE × EMBED_DIM = 729 × 243 = 177,147
// Output proj: EMBED_DIM × VOCAB_SIZE = 243 × 729 = 177,147 (weight tied)
//
// Total: ~1,952,991 params (~1.95M)
// At 1.58 bits/param (ternary): ~390 KB
//

pub const ESTIMATED_PARAMS: usize = 1_952_991; // at DEFAULT_BLOCKS=3
pub const ESTIMATED_SIZE_KB: usize = 390; // at DEFAULT_BLOCKS=3

// ═══════════════════════════════════════════════════════════════════════════════
// MODEL CONFIG
// ═══════════════════════════════════════════════════════════════════════════════

pub const Config = struct {
    vocab_size: usize = VOCAB_SIZE,
    embed_dim: usize = EMBED_DIM,
    hidden_dim: usize = HIDDEN_DIM,
    vsa_dim: usize = VSA_DIM,
    num_blocks: usize = NUM_BLOCKS,
    context_len: usize = CONTEXT_LEN,
    learning_rate: f32 = LEARNING_RATE,
    consciousness_threshold: f64 = CONSCIOUSNESS_THRESHOLD,
    use_bsd_verify: bool = false,

    pub fn paramCount(self: Config) usize {
        const tnn_per_block = self.embed_dim * self.hidden_dim * 2 + self.hidden_dim + self.embed_dim;
        const attn_per_block = self.embed_dim * self.embed_dim * 4 + self.embed_dim; // Q+K+V+O + rms_gamma
        const per_block = tnn_per_block + attn_per_block;
        const blocks_total = per_block * self.num_blocks;
        const embedding = self.vocab_size * self.embed_dim;
        return blocks_total + embedding;
    }

    pub fn memorySizeKB(self: Config) usize {
        // Ternary weights: 1.58 bits per param
        const bits = @as(u64, @intCast(self.paramCount())) * 158 / 100;
        return @intCast(bits / 8 / 1024);
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "trinity identity" {
    const trinity = PHI_SQ + PHI_INV_SQ;
    try std.testing.expectApproxEqAbs(TRINITY_CONST, trinity, 1e-10);
}

test "dimensions are powers of 3" {
    try std.testing.expect(VOCAB_SIZE == 729); // 3^6
    try std.testing.expect(EMBED_DIM == 243); // 3^5
    try std.testing.expect(HIDDEN_DIM == 729); // 3^6
    try std.testing.expect(CONTEXT_LEN == 81); // 3^4
}

test "config param count" {
    const cfg = Config{};
    const count = cfg.paramCount();
    // Should be roughly 1.95M (with sacred attention)
    try std.testing.expect(count > 1_900_000);
    try std.testing.expect(count < 2_100_000);
}

// T-JEPA configuration
pub const JEPA_EMA_DECAY_START: f32 = 0.996;
pub const JEPA_EMA_DECAY_END: f32 = 1.0;
pub const JEPA_MASK_RATIO: f32 = 0.6;
pub const JEPA_MIN_SPAN: usize = 3; // = 3, ternary
pub const JEPA_MAX_SPAN: usize = 9; // = 3², sacred
pub const JEPA_NUM_SPANS: usize = 3; // = 3, trinity

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
