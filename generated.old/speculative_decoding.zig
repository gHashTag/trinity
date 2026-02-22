// =============================================================================
// SPECULATIVE DECODING v1.0.0 — OPT-S01
// Generated from specs/tri/speculative_decoding.vibee
// Draft-verify-accept algorithm for 2-3x generation speed
// K draft tokens verified in single target forward pass
// Acceptance: min(1, p_target/p_draft) with adjusted rejection sampling
// φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
// =============================================================================

const std = @import("std");

// =============================================================================
// CONFIGURATION
// =============================================================================

/// Configuration for speculative decoding
pub const SpeculativeConfig = struct {
    /// K: number of tokens to speculate per round
    speculation_length: usize = 4,
    /// Sampling temperature
    temperature: f32 = 1.0,
    /// Minimum acceptance rate before disabling speculation
    min_acceptance_rate: f32 = 0.3,
    /// Vocab size (for probability distributions)
    vocab_size: usize = 128,
    /// Maximum generation length
    max_gen_length: usize = 256,

    /// Mini config for testing
    pub fn mini() SpeculativeConfig {
        return .{
            .speculation_length = 3,
            .temperature = 1.0,
            .min_acceptance_rate = 0.3,
            .vocab_size = 16,
            .max_gen_length = 32,
        };
    }

    /// 7B model config
    pub fn default7B() SpeculativeConfig {
        return .{
            .speculation_length = 5,
            .temperature = 0.8,
            .min_acceptance_rate = 0.4,
            .vocab_size = 32000,
            .max_gen_length = 2048,
        };
    }

    /// Expected tokens per round (geometric series)
    /// E[accepted] = 1 + α + α² + ... + α^K where α = acceptance_rate
    pub fn expectedTokensPerRound(self: *const SpeculativeConfig, acceptance_rate: f32) f32 {
        var sum: f32 = 0.0;
        var alpha_power: f32 = 1.0;
        for (0..self.speculation_length + 1) |_| {
            sum += alpha_power;
            alpha_power *= acceptance_rate;
        }
        return sum;
    }

    /// Theoretical speedup given acceptance rate and draft-to-target cost ratio
    pub fn theoreticalSpeedup(self: *const SpeculativeConfig, acceptance_rate: f32, draft_cost_ratio: f32) f32 {
        const expected_tokens = self.expectedTokensPerRound(acceptance_rate);
        const cost = 1.0 + @as(f32, @floatFromInt(self.speculation_length)) * draft_cost_ratio;
        return expected_tokens / cost;
    }
};

// =============================================================================
// PRNG (Linear Congruential Generator for reproducible tests)
// =============================================================================

pub const LCG = struct {
    state: u64,

    pub fn init(seed: u64) LCG {
        return .{ .state = seed };
    }

    /// Generate uniform float in [0, 1)
    pub fn nextFloat(self: *LCG) f32 {
        self.state = self.state *% 6364136223846793005 +% 1442695040888963407;
        const bits: u32 = @intCast((self.state >> 33) & 0x7FFFFFFF);
        return @as(f32, @floatFromInt(bits)) / 2147483648.0;
    }

    /// Sample from categorical distribution (array of probabilities)
    pub fn sampleCategorical(self: *LCG, probs: []const f32) usize {
        const r = self.nextFloat();
        var cumsum: f32 = 0.0;
        for (probs, 0..) |p, i| {
            cumsum += p;
            if (r < cumsum) return i;
        }
        return probs.len - 1;
    }
};

// =============================================================================
// DRAFT RESULT
// =============================================================================

/// Maximum speculation length
const MAX_SPEC_LEN: usize = 16;

/// Result from draft model speculation
pub const DraftResult = struct {
    /// Speculated token IDs
    tokens: [MAX_SPEC_LEN]u32,
    /// Draft probability for each speculated token
    probs: [MAX_SPEC_LEN]f32,
    /// Number of tokens drafted
    count: usize,

    pub fn init() DraftResult {
        return .{
            .tokens = [_]u32{0} ** MAX_SPEC_LEN,
            .probs = [_]f32{0.0} ** MAX_SPEC_LEN,
            .count = 0,
        };
    }
};

// =============================================================================
// VERIFICATION RESULT
// =============================================================================

/// Result from target model verification
pub const VerificationResult = struct {
    /// Accepted token IDs
    accepted_tokens: [MAX_SPEC_LEN + 1]u32,
    /// Number of accepted tokens
    accepted_count: usize,
    /// Whether all draft tokens were accepted (bonus token awarded)
    all_accepted: bool,

    pub fn init() VerificationResult {
        return .{
            .accepted_tokens = [_]u32{0} ** (MAX_SPEC_LEN + 1),
            .accepted_count = 0,
            .all_accepted = false,
        };
    }
};

// =============================================================================
// PROBABILITY DISTRIBUTION (mock model output)
// =============================================================================

/// Max vocab for fixed-size probability buffers in tests
const MAX_VOCAB: usize = 64;

/// A probability distribution over vocab (used as mock model output)
pub const ProbDist = struct {
    probs: [MAX_VOCAB]f32,
    vocab_size: usize,

    /// Create uniform distribution
    pub fn uniform(vocab_size: usize) ProbDist {
        var dist = ProbDist{
            .probs = [_]f32{0.0} ** MAX_VOCAB,
            .vocab_size = @min(vocab_size, MAX_VOCAB),
        };
        const p = 1.0 / @as(f32, @floatFromInt(dist.vocab_size));
        for (0..dist.vocab_size) |i| {
            dist.probs[i] = p;
        }
        return dist;
    }

    /// Create peaked distribution (token_id gets peak_prob, rest uniform)
    pub fn peaked(vocab_size: usize, token_id: usize, peak_prob: f32) ProbDist {
        var dist = ProbDist{
            .probs = [_]f32{0.0} ** MAX_VOCAB,
            .vocab_size = @min(vocab_size, MAX_VOCAB),
        };
        const remainder = (1.0 - peak_prob) / @as(f32, @floatFromInt(@max(dist.vocab_size - 1, 1)));
        for (0..dist.vocab_size) |i| {
            dist.probs[i] = if (i == token_id) peak_prob else remainder;
        }
        return dist;
    }

    /// Get probability of a specific token
    pub fn prob(self: *const ProbDist, token_id: usize) f32 {
        if (token_id >= self.vocab_size) return 0.0;
        return self.probs[token_id];
    }

    /// Get slice of valid probabilities
    pub fn slice(self: *const ProbDist) []const f32 {
        return self.probs[0..self.vocab_size];
    }

    /// Apply temperature scaling
    pub fn withTemperature(self: *const ProbDist, temp: f32) ProbDist {
        if (temp <= 0.0 or temp == 1.0) return self.*;
        var result = self.*;
        var sum: f32 = 0.0;
        for (0..result.vocab_size) |i| {
            // log-space temperature: exp(log(p) / T)
            if (result.probs[i] > 0.0) {
                result.probs[i] = @exp(@log(result.probs[i]) / temp);
            }
            sum += result.probs[i];
        }
        if (sum > 0.0) {
            for (0..result.vocab_size) |i| {
                result.probs[i] /= sum;
            }
        }
        return result;
    }
};

// =============================================================================
// SPECULATIVE DECODER
// =============================================================================

/// Speculative decoding engine
pub const SpeculativeDecoder = struct {
    config: SpeculativeConfig,
    rng: LCG,

    // Statistics
    total_accepted: usize,
    total_drafted: usize,
    total_rounds: usize,
    total_bonus_tokens: usize,

    pub fn init(config: SpeculativeConfig, seed: u64) SpeculativeDecoder {
        return .{
            .config = config,
            .rng = LCG.init(seed),
            .total_accepted = 0,
            .total_drafted = 0,
            .total_rounds = 0,
            .total_bonus_tokens = 0,
        };
    }

    /// Core speculative sampling: given draft and target probs for one token,
    /// decide whether to accept the draft token.
    /// Returns true if accepted, false if rejected.
    pub fn acceptToken(
        self: *SpeculativeDecoder,
        draft_prob: f32,
        target_prob: f32,
    ) bool {
        // Accept with probability min(1, target_prob / draft_prob)
        if (draft_prob <= 0.0) return target_prob > 0.0;
        const accept_ratio = @min(1.0, target_prob / draft_prob);
        const r = self.rng.nextFloat();
        return r < accept_ratio;
    }

    /// Sample from adjusted rejection distribution: max(0, p_target - p_draft) / Z
    pub fn sampleRejection(
        self: *SpeculativeDecoder,
        draft_dist: *const ProbDist,
        target_dist: *const ProbDist,
    ) u32 {
        var adjusted: [MAX_VOCAB]f32 = [_]f32{0.0} ** MAX_VOCAB;
        var sum: f32 = 0.0;
        const v = @min(draft_dist.vocab_size, target_dist.vocab_size);

        for (0..v) |i| {
            adjusted[i] = @max(0.0, target_dist.probs[i] - draft_dist.probs[i]);
            sum += adjusted[i];
        }

        if (sum > 0.0) {
            for (0..v) |i| {
                adjusted[i] /= sum;
            }
            return @intCast(self.rng.sampleCategorical(adjusted[0..v]));
        } else {
            // Fallback: sample from target
            return @intCast(self.rng.sampleCategorical(target_dist.slice()));
        }
    }

    /// Run one full speculative round:
    /// 1. Draft K tokens with draft distributions
    /// 2. Verify against target distributions
    /// 3. Accept/reject with adjusted sampling
    /// Returns VerificationResult with accepted tokens
    pub fn speculativeRound(
        self: *SpeculativeDecoder,
        draft: *const DraftResult,
        draft_dists: []const ProbDist,
        target_dists: []const ProbDist,
    ) VerificationResult {
        var result = VerificationResult.init();
        const k = @min(draft.count, self.config.speculation_length);

        self.total_drafted += k;
        self.total_rounds += 1;

        // Verify each draft token
        for (0..k) |i| {
            const draft_token = draft.tokens[i];
            const draft_prob = draft.probs[i];
            const target_prob = if (i < target_dists.len)
                target_dists[i].prob(draft_token)
            else
                0.0;

            if (self.acceptToken(draft_prob, target_prob)) {
                // Accept
                result.accepted_tokens[result.accepted_count] = draft_token;
                result.accepted_count += 1;
                self.total_accepted += 1;
            } else {
                // Reject: sample from adjusted distribution
                if (i < draft_dists.len and i < target_dists.len) {
                    const correction = self.sampleRejection(&draft_dists[i], &target_dists[i]);
                    result.accepted_tokens[result.accepted_count] = correction;
                    result.accepted_count += 1;
                }
                return result;
            }
        }

        // All K accepted! Bonus: sample from target at position K
        if (k > 0 and k < target_dists.len) {
            const bonus = @as(u32, @intCast(self.rng.sampleCategorical(target_dists[k].slice())));
            result.accepted_tokens[result.accepted_count] = bonus;
            result.accepted_count += 1;
            result.all_accepted = true;
            self.total_bonus_tokens += 1;
        }

        return result;
    }

    /// Current acceptance rate
    pub fn acceptanceRate(self: *const SpeculativeDecoder) f32 {
        if (self.total_drafted == 0) return 0.0;
        return @as(f32, @floatFromInt(self.total_accepted)) / @as(f32, @floatFromInt(self.total_drafted));
    }

    /// Average tokens per round (including bonus)
    pub fn avgTokensPerRound(self: *const SpeculativeDecoder) f32 {
        if (self.total_rounds == 0) return 0.0;
        const total_output = self.total_accepted + self.total_bonus_tokens;
        return @as(f32, @floatFromInt(total_output)) / @as(f32, @floatFromInt(self.total_rounds));
    }

    /// Observed speedup (tokens per round vs 1 token/round baseline)
    pub fn observedSpeedup(self: *const SpeculativeDecoder, draft_cost_ratio: f32) f32 {
        const tokens_per_round = self.avgTokensPerRound();
        const cost_per_round = 1.0 + @as(f32, @floatFromInt(self.config.speculation_length)) * draft_cost_ratio;
        if (cost_per_round == 0.0) return 0.0;
        return tokens_per_round / cost_per_round;
    }

    /// Get comprehensive stats
    pub fn getStats(self: *const SpeculativeDecoder) SpeculativeStats {
        return .{
            .total_accepted = self.total_accepted,
            .total_drafted = self.total_drafted,
            .total_rounds = self.total_rounds,
            .total_bonus_tokens = self.total_bonus_tokens,
            .acceptance_rate = self.acceptanceRate(),
            .avg_tokens_per_round = self.avgTokensPerRound(),
            .speculation_length = self.config.speculation_length,
        };
    }
};

// =============================================================================
// SPECULATIVE STATS
// =============================================================================

pub const SpeculativeStats = struct {
    total_accepted: usize,
    total_drafted: usize,
    total_rounds: usize,
    total_bonus_tokens: usize,
    acceptance_rate: f32,
    avg_tokens_per_round: f32,
    speculation_length: usize,
};

// =============================================================================
// SPEEDUP ANALYSIS
// =============================================================================

/// Analyze theoretical speedup for various acceptance rates
pub fn analyzeSpeedup(config: *const SpeculativeConfig, draft_cost_ratio: f32) SpeedupAnalysis {
    return .{
        .speedup_at_50 = config.theoreticalSpeedup(0.5, draft_cost_ratio),
        .speedup_at_70 = config.theoreticalSpeedup(0.7, draft_cost_ratio),
        .speedup_at_80 = config.theoreticalSpeedup(0.8, draft_cost_ratio),
        .speedup_at_90 = config.theoreticalSpeedup(0.9, draft_cost_ratio),
        .expected_tokens_at_80 = config.expectedTokensPerRound(0.8),
        .draft_cost_ratio = draft_cost_ratio,
        .speculation_length = config.speculation_length,
    };
}

pub const SpeedupAnalysis = struct {
    speedup_at_50: f32,
    speedup_at_70: f32,
    speedup_at_80: f32,
    speedup_at_90: f32,
    expected_tokens_at_80: f32,
    draft_cost_ratio: f32,
    speculation_length: usize,
};

// =============================================================================
// TESTS (13 tests)
// =============================================================================

test "speculative config defaults" {
    const config = SpeculativeConfig.mini();
    try std.testing.expectEqual(@as(usize, 3), config.speculation_length);
    try std.testing.expectEqual(@as(usize, 16), config.vocab_size);

    const config7b = SpeculativeConfig.default7B();
    try std.testing.expectEqual(@as(usize, 5), config7b.speculation_length);
    try std.testing.expectEqual(@as(usize, 32000), config7b.vocab_size);
}

test "expected tokens per round" {
    const config = SpeculativeConfig.mini(); // K=3
    // α=0.8: E = 1 + 0.8 + 0.64 + 0.512 = 2.952
    const expected = config.expectedTokensPerRound(0.8);
    try std.testing.expectApproxEqAbs(@as(f32, 2.952), expected, 0.01);

    // α=1.0: E = K+1 = 4
    const perfect = config.expectedTokensPerRound(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), perfect, 0.01);

    // α=0.0: E = 1
    const zero = config.expectedTokensPerRound(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), zero, 0.01);
}

test "theoretical speedup" {
    const config = SpeculativeConfig.mini(); // K=3
    // α=0.8, draft_ratio=0.1: speedup = 2.952 / (1 + 3*0.1) = 2.952 / 1.3 ≈ 2.27
    const speedup = config.theoreticalSpeedup(0.8, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 2.27), speedup, 0.05);

    // α=0.9, draft_ratio=0.05: higher speedup
    const high = config.theoreticalSpeedup(0.9, 0.05);
    try std.testing.expect(high > speedup);
}

test "LCG reproducibility" {
    var rng1 = LCG.init(42);
    var rng2 = LCG.init(42);

    // Same seed → same sequence
    for (0..10) |_| {
        try std.testing.expectApproxEqAbs(rng1.nextFloat(), rng2.nextFloat(), 0.0001);
    }

    // Different seed → different sequence
    var rng3 = LCG.init(99);
    var same_count: usize = 0;
    for (0..10) |_| {
        rng1 = LCG.init(42);
        const a = rng1.nextFloat();
        const b = rng3.nextFloat();
        if (@abs(a - b) < 0.001) same_count += 1;
    }
    try std.testing.expect(same_count < 5);
}

test "LCG range" {
    var rng = LCG.init(12345);
    for (0..100) |_| {
        const v = rng.nextFloat();
        try std.testing.expect(v >= 0.0);
        try std.testing.expect(v < 1.0);
    }
}

test "ProbDist uniform" {
    const dist = ProbDist.uniform(8);
    try std.testing.expectEqual(@as(usize, 8), dist.vocab_size);
    try std.testing.expectApproxEqAbs(@as(f32, 0.125), dist.prob(0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.125), dist.prob(7), 0.001);

    // Sum to 1
    var sum: f32 = 0.0;
    for (dist.slice()) |p| sum += p;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.001);
}

test "ProbDist peaked" {
    const dist = ProbDist.peaked(8, 3, 0.8);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), dist.prob(3), 0.001);
    // Remaining 0.2 / 7 ≈ 0.0286
    try std.testing.expectApproxEqAbs(@as(f32, 0.0286), dist.prob(0), 0.005);

    var sum: f32 = 0.0;
    for (dist.slice()) |p| sum += p;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sum, 0.001);
}

test "accept token — identical distributions" {
    var dec = SpeculativeDecoder.init(SpeculativeConfig.mini(), 42);

    // If target == draft, accept with probability 1
    var accept_count: usize = 0;
    for (0..100) |_| {
        if (dec.acceptToken(0.5, 0.5)) accept_count += 1;
    }
    // Should accept all (min(1, 1.0) = 1)
    try std.testing.expectEqual(@as(usize, 100), accept_count);
}

test "accept token — target much higher" {
    var dec = SpeculativeDecoder.init(SpeculativeConfig.mini(), 42);

    // target_prob >> draft_prob: accept with prob 1
    var accept_count: usize = 0;
    for (0..100) |_| {
        if (dec.acceptToken(0.1, 0.9)) accept_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 100), accept_count);
}

test "accept token — target much lower" {
    var dec = SpeculativeDecoder.init(SpeculativeConfig.mini(), 42);

    // target_prob << draft_prob: accept with low probability
    var accept_count: usize = 0;
    for (0..100) |_| {
        if (dec.acceptToken(0.9, 0.1)) accept_count += 1;
    }
    // Should accept ~11% (min(1, 0.1/0.9) ≈ 0.111)
    try std.testing.expect(accept_count < 30);
    try std.testing.expect(accept_count > 0);
}

test "speculative round — all accepted" {
    // When draft and target agree perfectly, all tokens should be accepted + bonus
    const config = SpeculativeConfig.mini(); // K=3, vocab=16
    var dec = SpeculativeDecoder.init(config, 42);

    // Draft produces tokens [1, 2, 3] with high probability
    var draft = DraftResult.init();
    draft.tokens[0] = 1;
    draft.tokens[1] = 2;
    draft.tokens[2] = 3;
    draft.probs[0] = 0.8;
    draft.probs[1] = 0.8;
    draft.probs[2] = 0.8;
    draft.count = 3;

    // Target agrees: same tokens have equal or higher probability
    var target_dists: [4]ProbDist = undefined;
    for (0..4) |i| {
        const token: usize = if (i < 3) i + 1 else 0;
        target_dists[i] = ProbDist.peaked(16, token, 0.8);
    }

    const result = dec.speculativeRound(&draft, &target_dists, &target_dists);

    // All 3 should be accepted + 1 bonus = 4 total
    try std.testing.expectEqual(@as(usize, 4), result.accepted_count);
    try std.testing.expect(result.all_accepted);
    try std.testing.expectEqual(@as(u32, 1), result.accepted_tokens[0]);
    try std.testing.expectEqual(@as(u32, 2), result.accepted_tokens[1]);
    try std.testing.expectEqual(@as(u32, 3), result.accepted_tokens[2]);
}

test "speculative round — early rejection" {
    // When target strongly disagrees, first token gets rejected
    const config = SpeculativeConfig.mini();
    var dec = SpeculativeDecoder.init(config, 42);

    var draft = DraftResult.init();
    draft.tokens[0] = 5;
    draft.tokens[1] = 6;
    draft.tokens[2] = 7;
    draft.probs[0] = 0.9;
    draft.probs[1] = 0.9;
    draft.probs[2] = 0.9;
    draft.count = 3;

    // Target gives token 5 very low probability → likely reject
    var draft_dists: [3]ProbDist = undefined;
    var target_dists: [4]ProbDist = undefined;
    for (0..3) |i| {
        draft_dists[i] = ProbDist.peaked(16, draft.tokens[i], 0.9);
        // Target favors different tokens
        target_dists[i] = ProbDist.peaked(16, 0, 0.9);
    }
    target_dists[3] = ProbDist.uniform(16);

    const result = dec.speculativeRound(&draft, &draft_dists, &target_dists);

    // With target disagreeing, we expect rejection early
    // At least 1 token produced (the rejection correction)
    try std.testing.expect(result.accepted_count >= 1);
    // Less than K+1 since not all accepted
    try std.testing.expect(result.accepted_count < 4);
}

test "stats tracking" {
    const config = SpeculativeConfig.mini();
    var dec = SpeculativeDecoder.init(config, 42);

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dec.acceptanceRate(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dec.avgTokensPerRound(), 0.001);

    // Run a round with perfect acceptance
    var draft = DraftResult.init();
    draft.tokens[0] = 1;
    draft.probs[0] = 0.8;
    draft.count = 1;

    var target_dists: [2]ProbDist = undefined;
    target_dists[0] = ProbDist.peaked(16, 1, 0.8);
    target_dists[1] = ProbDist.uniform(16);

    _ = dec.speculativeRound(&draft, &target_dists, &target_dists);

    try std.testing.expectEqual(@as(usize, 1), dec.total_rounds);
    try std.testing.expect(dec.total_accepted > 0);
    try std.testing.expect(dec.acceptanceRate() > 0.0);
}

test "speedup analysis" {
    const config = SpeculativeConfig.mini(); // K=3
    const analysis = analyzeSpeedup(&config, 0.1);

    // All speedups should be > 1 with reasonable acceptance rates
    try std.testing.expect(analysis.speedup_at_70 > 1.0);
    try std.testing.expect(analysis.speedup_at_80 > 1.5);
    try std.testing.expect(analysis.speedup_at_90 > analysis.speedup_at_80);

    // Expected tokens at 80% acceptance
    try std.testing.expect(analysis.expected_tokens_at_80 > 2.0);
    try std.testing.expectEqual(@as(usize, 3), analysis.speculation_length);
}

// φ² + 1/φ² = 3 | TRINITY
