// @origin(spec:loss.tri) @regen(manual-impl)
// HSLM — Advanced Loss Functions
// Cross-entropy, contrastive, KL divergence, triplet, label smoothing
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;

// ═════════════════════════════════════════════════════════════════════════════
// LOSS FUNCTION TYPES
// ═══════════════════════════════════════════════════════════════════════

/// Loss function configuration
pub const LossConfig = struct {
    /// Base loss function
    loss_fn: LossType,
    /// Label smoothing factor (0 = no smoothing, 0.1 = typical)
    label_smoothing: f32 = 0.1,
    /// Temperature for soft targets
    temperature: f32 = 1.0,
    /// Focal loss gamma (0 = standard CE, >0 = focal)
    focal_gamma: f32 = 0.0,

    pub fn init() LossConfig {
        return LossConfig{
            .loss_fn = .cross_entropy,
            .label_smoothing = 0.1,
            .temperature = 1.0,
            .focal_gamma = 0.0,
        };
    }
};

pub const LossType = enum {
    cross_entropy,
    contrastive,
    kl_divergence,
    triplet,
    focal_cross_entropy,
};

// ═════════════════════════════════════════════════════════════════════════════
// CROSS-ENTROPY LOSS
// ═══════════════════════════════════════════════════════════════════════════

/// Cross-entropy loss for a single position with label smoothing
pub fn crossEntropyLoss(logits: []const f32, target: u16, config: LossConfig) f32 {
    // Softmax + log with label smoothing
    var probs: [VOCAB_SIZE]f32 = undefined;
    model_mod.softmaxWithTemp(logits, config.temperature, &probs);

    // Apply label smoothing
    const smooth_const: f32 = config.label_smoothing / @as(f32, @floatFromInt(VOCAB_SIZE));
    var smoothed_probs: [VOCAB_SIZE]f32 = undefined;
    for (0..VOCAB_SIZE) |i| {
        smoothed_probs[i] = probs[i] * (1.0 - config.label_smoothing);
    }

    // Add smooth_const to target probability
    const target_prob = smoothed_probs[@as(usize, target)] + smooth_const;

    const clamped = @max(target_prob, 1e-7);
    return -@log(clamped);
}

/// Cross-entropy loss with focal weighting
pub fn focalCrossEntropyLoss(logits: []const f32, target: u16, config: LossConfig) f32 {
    if (config.focal_gamma == 0) return crossEntropyLoss(logits, target, config);

    var probs: [VOCAB_SIZE]f32 = undefined;
    model_mod.softmax(logits, &probs);

    const target_prob = probs[@as(usize, target)];

    // Compute focal weight
    const focal_weight = std.math.pow(f32, 1.0 - target_prob, config.focal_gamma);

    const clamped = @max(target_prob, 1e-7);
    return focal_weight * (-@log(clamped));
}

/// Average cross-entropy loss over a sequence
pub fn sequenceLoss(all_logits: []const f32, targets: []const u16, seq_len: usize, config: LossConfig) f32 {
    if (seq_len == 0) return 0.0;
    var total_loss: f64 = 0.0;

    for (0..seq_len) |pos| {
        const l_offset = pos * VOCAB_SIZE;
        const logits = all_logits[l_offset .. l_offset + VOCAB_SIZE];
        const loss = crossEntropyLoss(logits, targets[pos], config);
        total_loss += loss;
    }

    return @floatCast(total_loss / @as(f64, @floatFromInt(seq_len)));
}

// ═════════════════════════════════════════════════════════════════════════════════
// CONTRASTIVE LOSS
// ═══════════════════════════════════════════════════════════════════════════════════

/// Contrastive loss: pull anchor and positive closer, push negative away
/// L = -log( exp(anchor·pos) / (exp(anchor·pos) + sum(neg)) )
pub fn contrastiveLoss(
    anchor: []const f32,
    positive: []const f32,
    negative: []const f32,
) f32 {
    const embed_dim = @min(anchor.len, positive.len);

    // Dot products
    var pos_sim: f32 = 0.0;
    var neg_sim_sum: f32 = 0.0;

    for (0..embed_dim) |i| {
        pos_sim += anchor[i] * positive[i];
        for (negative) |neg_vec| {
            const neg_sim = anchor[i] * neg_vec[i];
            neg_sim_sum += @exp(neg_sim);
        }
    }

    const pos_exp = @exp(pos_sim);
    const denominator = pos_exp + neg_sim_sum;

    const clamped_denom = @max(denominator, 1e-6);
    return -@log(pos_exp / clamped_denom);
}

/// Sequence-level contrastive loss
pub fn contrastiveSequenceLoss(
    anchors: []const f32,
    positives: []const f32,
    negatives: []const f32,
    seq_len: usize,
) f32 {
    if (seq_len == 0) return 0.0;
    var total_loss: f64 = 0.0;

    const embed_dim = anchors.len / seq_len;

    for (0..seq_len) |pos| {
        const a_offset = pos * embed_dim;
        const p_offset = pos * embed_dim;
        const anchor = anchors[a_offset .. a_offset + embed_dim];
        const positive = positives[p_offset .. p_offset + embed_dim];

        // Use corresponding negatives - assume negatives are organized as sequence of vectors
        const neg_embed_dim = if (negatives.len >= seq_len) negatives.len / seq_len else embed_dim;
        const n_offset = pos * neg_embed_dim;
        const end_offset = @min(n_offset + embed_dim, negatives.len);
        const negs = negatives[n_offset..end_offset];

        total_loss += contrastiveLoss(anchor, positive, negs);
    }

    return @floatCast(total_loss / @as(f64, @floatFromInt(seq_len)));
}

// ═════════════════════════════════════════════════════════════════════════════════
// KL DIVERGENCE
// ═════════════════════════════════════════════════════════════════════════════════════

/// KL divergence: D_KL(P || Q) = sum(P * log(P/Q))
pub fn klDivergence(p: []const f32, q: []const f32) f32 {
    if (p.len != q.len) return 0.0;

    var kl: f64 = 0.0;
    for (0..p.len) |i| {
        const pi = p[i];
        const qi = q[i];

        // Clamp to avoid log(0)
        const clamped_p = @max(pi, 1e-7);
        const clamped_q = @max(qi, 1e-7);

        const log_ratio = @log(clamped_p / clamped_q);
        kl += pi * log_ratio;
    }

    return @floatCast(kl);
}

/// Symmetric KL divergence (for mutual information estimation)
pub fn symmetricKlDivergence(p: []const f32, q: []const f32) f32 {
    const kl_pq = klDivergence(p, q);
    const kl_qp = klDivergence(q, p);
    return (kl_pq + kl_qp) / 2.0;
}

// ═════════════════════════════════════════════════════════════════════════════════
// TRIPLET LOSS
// ═══════════════════════════════════════════════════════════════════════════════════════

/// Triplet loss: max(0, d_pos - d_neg) + margin
pub fn tripletLoss(anchor: []const f32, positive: []const f32, negative: []const f32, margin: f32) f32 {
    const embed_dim = @min(anchor.len, @min(positive.len, negative.len));

    // Euclidean distances
    var d_pos_sq: f64 = 0.0;
    var d_neg_sq: f64 = 0.0;

    for (0..embed_dim) |i| {
        const ap_diff = anchor[i] - positive[i];
        const an_diff = anchor[i] - negative[i];
        d_pos_sq += @as(f64, ap_diff) * ap_diff;
        d_neg_sq += @as(f64, an_diff) * an_diff;
    }

    const d_pos = @sqrt(d_pos_sq);
    const d_neg = @sqrt(d_neg_sq);

    // Triplet loss with margin
    const triplet = d_pos - d_neg + margin;
    return @max(0.0, triplet);
}

/// Batch triplet loss
pub fn tripletBatchLoss(
    anchors: []const f32,
    positives: []const f32,
    negatives: []const f32,
    batch_size: usize,
    margin: f32,
) f32 {
    if (batch_size == 0) return 0.0;
    var total_loss: f64 = 0.0;

    const embed_dim = anchors.len / batch_size;

    for (0..batch_size) |b| {
        const a_offset = b * embed_dim;
        const p_offset = b * embed_dim;
        const n_offset = b * embed_dim;

        const anchor = anchors[a_offset .. a_offset + embed_dim];
        const positive = positives[p_offset .. p_offset + embed_dim];
        const negative = negatives[n_offset .. n_offset + embed_dim];

        total_loss += tripletLoss(anchor, positive, negative, margin);
    }

    return @floatCast(total_loss / @as(f64, @floatFromInt(batch_size)));
}

// ═══════════════════════════════════════════════════════════════════════════════════
// LOSS SELECTION
// ═════════════════════════════════════════════════════════════════════════════════════

/// Compute loss based on configuration
pub fn computeLoss(logits: []const f32, target: u16, config: LossConfig) f32 {
    return switch (config.loss_fn) {
        .cross_entropy => crossEntropyLoss(logits, target, config),
        .focal_cross_entropy => focalCrossEntropyLoss(logits, target, config),
        .contrastive => {
            // For contrastive, need embeddings (not logits)
            // Return placeholder
            return 0.0;
        },
        .kl_divergence => {
            // For KL divergence, need two distributions
            return 0.0;
        },
        .triplet => {
            // For triplet loss, need embeddings
            return 0.0;
        },
    };
}

// ═══════════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════════════════════════

test "cross entropy with label smoothing" {
    var logits: [VOCAB_SIZE]f32 = [_]f32{0.0} ** VOCAB_SIZE;
    logits[42] = 10.0; // High logit for target

    const config = LossConfig{
        .loss_fn = .cross_entropy,
        .label_smoothing = 0.1,
        .temperature = 1.0,
    };

    const loss = crossEntropyLoss(&logits, 42, config);

    // With smoothing, loss should be higher (less confident)
    try std.testing.expect(loss > 0.0);
}

test "contrastive loss" {
    const anchor = [_]f32{ 1.0, 0.0, 0.0 };
    const positive = [_]f32{ 2.0, 0.0, 0.0 };
    const negative = [_]f32{ -1.0, 0.0, 0.0 };

    const loss = contrastiveLoss(&anchor, &positive, &negative);

    // Anchor and positive should be close, loss should be low
    try std.testing.expect(loss < 0.1);
}

test "triplet loss" {
    const anchor = [_]f32{ 1.0, 0.0, 0.0 };
    const positive = [_]f32{ 2.0, 0.0, 0.0 };
    const negative = [_]f32{ -1.0, 0.0, 0.0 };

    const loss = tripletLoss(&anchor, &positive, &negative, 0.5);

    // d_pos = 1, d_neg = 2, triplet = 1 - 2 + 0.5 = -0.5
    // max(0, -0.5) = 0
    try std.testing.expectApproxEqAbs(0.5, loss, 0.01);
}

test "KL divergence" {
    const p = [_]f32{ 0.5, 0.3, 0.2 };
    const q = [_]f32{ 0.6, 0.2, 0.3 };

    const kl = klDivergence(&p, &q);

    // Should be positive (KL is always >= 0)
    try std.testing.expect(kl >= 0.0);
}

test "focal loss" {
    var logits: [VOCAB_SIZE]f32 = [_]f32{0.0} ** VOCAB_SIZE;
    logits[42] = 10.0; // High confidence for target

    const config = LossConfig{
        .loss_fn = .focal_cross_entropy,
        .label_smoothing = 0.0,
        .temperature = 1.0,
        .focal_gamma = 2.0,
    };

    const loss = focalCrossEntropyLoss(&logits, 42, config);

    // Focal loss should be lower than standard CE (focus on well-classified example)
    const ce_loss = crossEntropyLoss(&logits, 42, LossConfig{
        .loss_fn = .cross_entropy,
        .label_smoothing = 0.0,
        .temperature = 1.0,
    });

    try std.testing.expect(loss < ce_loss);
}

test "sequence loss" {
    const seq_len = 3;

    var logits: [VOCAB_SIZE * seq_len]f32 = undefined;
    @memset(&logits, 0.0);

    // Set some logits
    logits[0 * VOCAB_SIZE + 42] = 5.0; // Correct for position 0
    logits[1 * VOCAB_SIZE + 100] = 10.0; // High for position 1
    logits[2 * VOCAB_SIZE + 42] = 2.0; // Correct for position 2
    logits[3 * VOCAB_SIZE + 100] = 1.0; // High for position 3
    logits[4 * VOCAB_SIZE + 42] = 8.0; // High for position 4
    logits[5 * VOCAB_SIZE + 42] = 3.0; // Correct for position 5

    const targets = [_]u16{ 42, 100, 42, 100, 42, 100 };

    const config = LossConfig{
        .loss_fn = .cross_entropy,
        .label_smoothing = 0.0,
        .temperature = 1.0,
    };

    const loss = sequenceLoss(&logits, &targets, seq_len, config);

    // Average should be reasonable
    try std.testing.expect(loss >= 0.0 and loss <= 5.0);
}

test "loss config init" {
    const config = LossConfig.init();

    try std.testing.expectEqual(LossType.cross_entropy, config.loss_fn);
    try std.testing.expectEqual(@as(f32, 0.1), config.label_smoothing);
    try std.testing.expectEqual(@as(f32, 1.0), config.temperature);
}

test "loss config with focal gamma" {
    const config = LossConfig{
        .loss_fn = .focal_cross_entropy,
        .label_smoothing = 0.0,
        .temperature = 1.0,
        .focal_gamma = 2.5,
    };

    try std.testing.expectEqual(@as(f32, 2.5), config.focal_gamma);
}

// φ² + 1/φ² = 3 | TRINITY
