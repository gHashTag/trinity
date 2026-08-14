const std = @import("std");
const sacred = @import("sacred_constants.zig");
const vocab_audit = @import("vocab_audit.zig");

pub const PG_CONFIG = TrinityPGConfig{
    .vocab_size = 729,
    .embed_dim = 243,
    .hidden_dim = 729,
    .context_len = 81,
    .num_blocks = 9,
    .num_heads = 9,
    .head_dim = 27,
    .ffn_hidden = 729,
    .bits_per_weight = 2,
    .batch_size = 66,
    .lr = 3e-4,
    .lr_min = 1e-5,
    .lamb_clamp = 10.0,
    .stable_ratio = 0.02,
    .grad_clip = 1.0,
};

pub const TrinityPGConfig = struct {
    vocab_size: usize,
    embed_dim: usize,
    hidden_dim: usize,
    context_len: usize,
    num_blocks: usize,
    num_heads: usize,
    head_dim: usize,
    ffn_hidden: usize,
    bits_per_weight: usize,
    batch_size: usize,
    lr: f64,
    lr_min: f64,
    lamb_clamp: f64,
    stable_ratio: f64,
    grad_clip: f64,

    pub fn totalParams(self: TrinityPGConfig) usize {
        const embedding = self.vocab_size * self.embed_dim;
        const per_block_attn = 4 * self.embed_dim * self.embed_dim;
        const per_block_ffn = 3 * self.embed_dim * self.ffn_hidden;
        const per_block = per_block_attn + per_block_ffn;
        const all_blocks = self.num_blocks * per_block;
        const lm_head = self.vocab_size * self.embed_dim;
        return embedding + all_blocks + lm_head;
    }

    pub fn modelSizeBytes(self: TrinityPGConfig) usize {
        return self.totalParams() * self.bits_per_weight / 8;
    }

    pub fn modelSizeMB(self: TrinityPGConfig) f64 {
        return @as(f64, @floatFromInt(self.modelSizeBytes())) / (1024.0 * 1024.0);
    }

    pub fn fitsBudget(self: TrinityPGConfig, budget_mb: f64) bool {
        return self.modelSizeMB() <= budget_mb;
    }

    pub fn allDimsPowerOf3(self: TrinityPGConfig) bool {
        return isPowerOf3(self.vocab_size) and
            isPowerOf3(self.embed_dim) and
            isPowerOf3(self.context_len) and
            isPowerOf3(self.num_blocks) and
            isPowerOf3(self.num_heads) and
            isPowerOf3(self.head_dim) and
            isPowerOf3(self.ffn_hidden);
    }

    pub fn squareAttentionHolds(self: TrinityPGConfig) bool {
        if (self.context_len % self.head_dim != 0) return false;
        return isPowerOf3(self.context_len / self.head_dim);
    }

    pub fn validate(self: TrinityPGConfig) !void {
        if (!self.allDimsPowerOf3()) return error.NonPowerOf3Dimension;
        if (!self.squareAttentionHolds()) return error.SquareAttentionViolation;
        if (!self.fitsBudget(16.0)) return error.ExceedsBudget;
        if (self.vocab_size != 729) return error.WrongVocabSize;
    }
};

fn isPowerOf3(n: usize) bool {
    if (n == 0) return false;
    var v = n;
    while (v % 3 == 0) v /= 3;
    return v == 1;
}

test "PG config fits 16MB budget" {
    try std.testing.expect(PG_CONFIG.fitsBudget(16.0));
}

test "PG config all dims are 3^k" {
    try std.testing.expect(PG_CONFIG.allDimsPowerOf3());
}

test "PG config square attention holds" {
    try std.testing.expect(PG_CONFIG.squareAttentionHolds());
    try std.testing.expect(@mod(PG_CONFIG.context_len, PG_CONFIG.head_dim) == 0);
}

test "PG config validate passes" {
    try PG_CONFIG.validate();
}

test "PG config model size under 16MB" {
    const size_mb = PG_CONFIG.modelSizeMB();
    try std.testing.expect(size_mb > 0);
    try std.testing.expect(size_mb <= 16.0);
}

test "isPowerOf3" {
    try std.testing.expect(isPowerOf3(1));
    try std.testing.expect(isPowerOf3(3));
    try std.testing.expect(isPowerOf3(9));
    try std.testing.expect(isPowerOf3(27));
    try std.testing.expect(isPowerOf3(81));
    try std.testing.expect(isPowerOf3(243));
    try std.testing.expect(isPowerOf3(729));
    try std.testing.expect(!isPowerOf3(2));
    try std.testing.expect(!isPowerOf3(4));
    try std.testing.expect(!isPowerOf3(0));
    try std.testing.expect(!isPowerOf3(10));
}

test "PG config detailed size breakdown" {
    const cfg = PG_CONFIG;
    const embedding = cfg.vocab_size * cfg.embed_dim;
    const per_block = 4 * cfg.embed_dim * cfg.embed_dim + 3 * cfg.embed_dim * cfg.ffn_hidden;
    const all_blocks = cfg.num_blocks * per_block;
    const lm_head = cfg.vocab_size * cfg.embed_dim;

    try std.testing.expect(embedding > 0);
    try std.testing.expect(all_blocks > 0);
    try std.testing.expect(lm_head > 0);

    const total = cfg.totalParams();
    try std.testing.expect(total == embedding + all_blocks + lm_head);
}
