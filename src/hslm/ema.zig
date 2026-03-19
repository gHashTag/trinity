// @origin(manual) @regen(pending)
// T-JEPA — EMA (Exponential Moving Average) Weight Synchronization
// Target encoder = EMA of online encoder shadow floats
// After EMA update, target requantizes ternary weights from updated shadows
//
// φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");

const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const VOCAB_SIZE = constants.VOCAB_SIZE;
const NUM_BLOCKS = constants.NUM_BLOCKS;

// ═══════════════════════════════════════════════════════════════════════════════
// EMA SYNC
// ═══════════════════════════════════════════════════════════════════════════════

pub const EmaSync = struct {
    decay_start: f32, // 0.996 — initial decay (more online influence)
    decay_end: f32, // 1.0 — final decay (target freezes)

    /// Update target shadow floats via EMA: target[i] = decay * target[i] + (1-decay) * online[i]
    pub fn updateShadows(target_shadow: []f32, online_shadow: []const f32, decay: f32) void {
        std.debug.assert(target_shadow.len == online_shadow.len);
        const one_minus_decay = 1.0 - decay;
        for (target_shadow, online_shadow) |*t, o| {
            t.* = decay * t.* + one_minus_decay * o;
        }
    }

    /// Sync all shadow weights from online encoder to target encoder
    /// Operates on: output_shadow, per-block TNN shadows + biases, sacred attention shadows + rms_gamma
    pub fn syncModels(self: *const EmaSync, target: *model_mod.HSLM, online: *const model_mod.HSLM, step: u32, total_steps: u32) void {
        const decay = scheduledDecay(step, total_steps, self.decay_start, self.decay_end);

        // Output projection shadows
        updateShadows(target.output_shadow, online.output_shadow, decay);

        // Per-block params
        for (&target.blocks, &online.blocks) |*t_block, *o_block| {
            // TNN dense shadows
            updateShadows(t_block.tnn.shadow_up, o_block.tnn.shadow_up, decay);
            updateShadows(t_block.tnn.shadow_down, o_block.tnn.shadow_down, decay);
            updateShadows(t_block.tnn.bias_up, o_block.tnn.bias_up, decay);
            updateShadows(t_block.tnn.bias_down, o_block.tnn.bias_down, decay);

            // Sacred attention shadows
            updateShadows(t_block.sacred_attn.shadow_q, o_block.sacred_attn.shadow_q, decay);
            updateShadows(t_block.sacred_attn.shadow_k, o_block.sacred_attn.shadow_k, decay);
            updateShadows(t_block.sacred_attn.shadow_v, o_block.sacred_attn.shadow_v, decay);
            updateShadows(t_block.sacred_attn.shadow_o, o_block.sacred_attn.shadow_o, decay);

            // RMS gamma
            updateShadows(t_block.sacred_attn.rms_gamma, o_block.sacred_attn.rms_gamma, decay);
        }

        // Embedding float table
        updateShadows(target.emb.float_table, online.emb.float_table, decay);
    }

    /// Current decay value at given step
    pub fn currentDecay(self: *const EmaSync, step: u32, total_steps: u32) f32 {
        return scheduledDecay(step, total_steps, self.decay_start, self.decay_end);
    }
};

/// Linear ramp from start to end over total_steps
pub fn scheduledDecay(step: u32, total_steps: u32, start: f32, end: f32) f32 {
    if (total_steps == 0) return end;
    const t = @min(@as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(total_steps)), 1.0);
    return start + (end - start) * t;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ema decay formula" {
    var target = [_]f32{ 1.0, 2.0, 3.0 };
    const online = [_]f32{ 0.0, 0.0, 0.0 };
    EmaSync.updateShadows(&target, &online, 0.996);
    // target[0] = 0.996 * 1.0 + 0.004 * 0.0 = 0.996
    try std.testing.expectApproxEqAbs(@as(f32, 0.996), target[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.992), target[1], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 2.988), target[2], 1e-5);
}

test "ema schedule ramp" {
    // At step 0 → start
    try std.testing.expectApproxEqAbs(@as(f32, 0.996), scheduledDecay(0, 100, 0.996, 1.0), 1e-6);
    // At step 50 → midpoint
    try std.testing.expectApproxEqAbs(@as(f32, 0.998), scheduledDecay(50, 100, 0.996, 1.0), 1e-6);
    // At step 100 → end
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), scheduledDecay(100, 100, 0.996, 1.0), 1e-6);
    // Beyond total → clamped to end
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), scheduledDecay(200, 100, 0.996, 1.0), 1e-6);
}

test "ema sync models" {
    const allocator = std.testing.allocator;

    var online = try model_mod.HSLM.init(allocator);
    defer online.deinit();
    var target = try model_mod.HSLM.init(allocator);
    defer target.deinit();

    const ema = EmaSync{ .decay_start = 0.0, .decay_end = 0.0 };
    // decay=0 means target = online (full copy)
    ema.syncModels(&target, &online, 0, 100);

    // After decay=0 sync, target shadows should equal online shadows
    for (target.output_shadow, online.output_shadow) |t, o| {
        try std.testing.expectApproxEqAbs(t, o, 1e-6);
    }
    // Check one block
    for (target.blocks[0].tnn.shadow_up, online.blocks[0].tnn.shadow_up) |t, o| {
        try std.testing.expectApproxEqAbs(t, o, 1e-6);
    }
}
