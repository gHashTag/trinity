// HSLM — Hybrid Symbolic Language Model
// Root module: re-exports all public API
//
// Architecture: TNN (System 1) + VSA (System 2) + BSD verification
// ~1.24M ternary parameters, ~248KB
//
// φ² + 1/φ² = 3 = TRINITY

pub const constants = @import("constants.zig");
pub const tokenizer = @import("tokenizer.zig");
pub const embedding = @import("embedding.zig");
pub const attention = @import("attention.zig");
pub const reasoning = @import("reasoning.zig");
pub const consciousness = @import("consciousness.zig");
pub const trinity_block = @import("trinity_block.zig");
pub const model = @import("model.zig");
pub const bsd_verify = @import("bsd_verify.zig");
pub const data = @import("data.zig");
pub const train = @import("train.zig");
pub const autograd = @import("autograd.zig");
pub const trainer = @import("trainer.zig");
pub const bench = @import("bench.zig");
pub const sacred_attention = @import("sacred_attention.zig");
pub const simd_ops = @import("simd_ops.zig");
pub const parallel = @import("parallel.zig");
pub const ste = @import("ste.zig");

// Re-export primary types
pub const HSLM = model.HSLM;
pub const Config = constants.Config;
pub const Tokenizer = tokenizer.Tokenizer;
pub const Embedding = embedding.Embedding;
pub const TrinityBlock = trinity_block.TrinityBlock;
pub const ConsciousnessGate = consciousness.ConsciousnessGate;
pub const Reasoning = reasoning.Reasoning;
pub const VSAAttention = attention.VSAAttention;
pub const Dataset = data.Dataset;
pub const Batch = data.Batch;
pub const Trainer = train.Trainer;
pub const TrainState = train.TrainState;
pub const Tensor = autograd.Tensor;
pub const AdamW = autograd.AdamW;
pub const FullTrainer = trainer.FullTrainer;
pub const TrainConfig = trainer.TrainConfig;
pub const TrainMetrics = trainer.TrainMetrics;
pub const BenchResult = bench.BenchResult;
pub const SacredAttention = sacred_attention.SacredAttention;
pub const ParallelTrainer = parallel.ParallelTrainer;
pub const SteMode = ste.SteMode;
pub const SteConfig = ste.SteConfig;

// Re-export constants
pub const VOCAB_SIZE = constants.VOCAB_SIZE;
pub const EMBED_DIM = constants.EMBED_DIM;
pub const HIDDEN_DIM = constants.HIDDEN_DIM;
pub const VSA_DIM = constants.VSA_DIM;
pub const NUM_BLOCKS = constants.NUM_BLOCKS;
pub const CONTEXT_LEN = constants.CONTEXT_LEN;
pub const PHI = constants.PHI;
pub const NUM_HEADS = constants.NUM_HEADS;
pub const HEAD_DIM = constants.HEAD_DIM;
pub const CONSCIOUSNESS_THRESHOLD = constants.CONSCIOUSNESS_THRESHOLD;

// Re-export utility functions
pub const softmax = model.softmax;
pub const crossEntropyLoss = train.crossEntropyLoss;
pub const sequenceLoss = train.sequenceLoss;
pub const cosineSimilarityTrit = attention.cosineSimilarityTrit;
pub const floatToTrit = embedding.Embedding.floatToTrit;
pub const tritToFloat = embedding.Embedding.tritToFloat;

// Comptime tests to ensure all modules compile
comptime {
    _ = constants;
    _ = tokenizer;
    _ = embedding;
    _ = attention;
    _ = reasoning;
    _ = consciousness;
    _ = trinity_block;
    _ = model;
    _ = bsd_verify;
    _ = data;
    _ = train;
    _ = autograd;
    _ = trainer;
    _ = bench;
    _ = sacred_attention;
    _ = simd_ops;
    _ = parallel;
    _ = ste;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INTEGRATION TESTS
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");

test "hslm full pipeline: tokenize → embed → forward → generate" {
    const allocator = std.testing.allocator;

    // 1. Tokenize
    var tok = try Tokenizer.init(allocator);
    defer tok.deinit();

    const text = "The quick brown fox";
    var tokens: [64]u16 = undefined;
    const n = tok.encode(text, &tokens);
    try std.testing.expect(n > 2); // BOS + content + EOS

    // 2. Create model
    var hslm = try HSLM.init(allocator);
    defer hslm.deinit();

    // 3. Forward pass
    var logits: [VOCAB_SIZE]f32 = undefined;
    hslm.forward(tokens[0..n], &logits);

    // 4. Verify logits are valid
    for (logits) |v| {
        try std.testing.expect(!std.math.isNan(v));
        try std.testing.expect(!std.math.isInf(v));
    }

    // 5. Generate next token
    const next = hslm.generate(tokens[0..n]);
    try std.testing.expect(next < VOCAB_SIZE);

    // 6. Check consciousness stats
    const stats = hslm.consciousnessStats();
    try std.testing.expect(stats.ratio >= 0.0);
    try std.testing.expect(stats.ratio <= 1.0);

    // 7. Decode back
    var output_tokens: [64]u16 = undefined;
    @memcpy(output_tokens[0..n], tokens[0..n]);
    output_tokens[n] = next;

    var decoded: [256]u8 = undefined;
    const m = tok.decode(output_tokens[0 .. n + 1], &decoded);
    try std.testing.expect(m > 0);
}

test "hslm parameter count matches estimate" {
    const allocator = std.testing.allocator;
    var hslm = try HSLM.init(allocator);
    defer hslm.deinit();

    const count = hslm.paramCount();
    try std.testing.expect(count > 1_900_000); // > 1.9M (with sacred attention)
    try std.testing.expect(count < 2_100_000); // < 2.1M
}

test "hslm bsd verification integration" {
    // Verify a known curve
    const result = bsd_verify.verifyClaim(.{
        .a = -1,
        .b = 0,
        .rank = 0,
        .l_value = 0.6555,
    });
    try std.testing.expect(result.is_consistent);
}

test "hslm autograd training step" {
    const allocator = std.testing.allocator;

    var hslm = try HSLM.init(allocator);
    defer hslm.deinit();

    var ds = try data.Dataset.init(allocator, 8);
    defer ds.deinit();
    try ds.addText("The quick brown fox jumps over the lazy dog many times today.");

    var ft = try FullTrainer.init(allocator, &hslm, &ds, TrainConfig{});
    defer ft.deinit();

    var batch_data = try data.Batch.init(allocator, 1, 8);
    defer batch_data.deinit();
    ds.nextBatch(&batch_data);

    const loss = ft.trainStep(batch_data.getInput(0), batch_data.getTarget(0));
    try std.testing.expect(!std.math.isNan(loss));
    try std.testing.expect(!std.math.isInf(loss));
    try std.testing.expect(loss > 0.0);
    try std.testing.expect(ft.metrics.step == 1);
}

test "hslm dual representation bridge" {
    // Float → Trit → Float roundtrip
    const float_in = [_]f32{ 0.9, -0.8, 0.0, 0.3, -0.5, 1.0, -1.0, 0.1 };
    var trit: [8]i8 = undefined;
    var float_out: [8]f32 = undefined;

    floatToTrit(&float_in, &trit);
    tritToFloat(&trit, &float_out);

    // Trit values should be {-1, 0, +1}
    for (trit) |t| {
        try std.testing.expect(t >= -1 and t <= 1);
    }

    // Float output should also be {-1.0, 0.0, +1.0}
    for (float_out) |v| {
        try std.testing.expect(v == -1.0 or v == 0.0 or v == 1.0);
    }
}
