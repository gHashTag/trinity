// @origin(spec:parallel.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
// HSLM — Parallel Batch Processing
// N workers process batch samples concurrently, then gradients are summed.
// Workers use initWorker() (no shadow weights) — saves ~7MB per worker.
//
// Architecture:
//   syncWeights(master → workers)
//   spawn workers: each processes batch_size/N samples (forward+backward)
//   accumulateGradsInto(workers → master)
//   master runs optimizerStep()

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const data_mod = @import("data.zig");
const autograd = @import("autograd.zig");
const trinity_block = @import("trinity_block.zig");
const sacred_attention_mod = @import("sacred_attention.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM = constants.EMBED_DIM;
const HIDDEN_DIM = constants.HIDDEN_DIM;
const CONTEXT_LEN = constants.CONTEXT_LEN;
const NUM_BLOCKS = constants.NUM_BLOCKS;

pub const N_WORKERS: usize = 6;

// ═══════════════════════════════════════════════════════════════════════════════
// PARALLEL TRAINER
// ═══════════════════════════════════════════════════════════════════════════════

pub const ParallelTrainer = struct {
    workers: [N_WORKERS]model_mod.HSLM,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self: Self = undefined;
        self.allocator = allocator;

        // Initialize worker-light models (no shadow weights)
        for (&self.workers) |*w| {
            w.* = try model_mod.HSLM.initWorker(allocator);
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        for (&self.workers) |*w| w.deinit();
    }

    /// Copy ternary weights + biases from source model to all workers.
    /// Call after master's requantize() and before the next forward pass.
    /// ~2MB per worker copy at ~100GB/s bandwidth = ~20us total.
    pub fn syncWeights(self: *Self, source: *const model_mod.HSLM) void {
        for (&self.workers) |*w| {
            // Output projection
            @memcpy(w.output_weights, source.output_weights);
            @memcpy(w.output_bias, source.output_bias);

            // Per-block weights
            for (0..source.blocks.len) |b| {
                // TNN weights + biases
                @memcpy(w.blocks[b].tnn.weights_up, source.blocks[b].tnn.weights_up);
                @memcpy(w.blocks[b].tnn.weights_down, source.blocks[b].tnn.weights_down);
                @memcpy(w.blocks[b].tnn.bias_up, source.blocks[b].tnn.bias_up);
                @memcpy(w.blocks[b].tnn.bias_down, source.blocks[b].tnn.bias_down);

                // Sacred Attention weights + RMS gamma
                @memcpy(w.blocks[b].sacred_attn.w_q, source.blocks[b].sacred_attn.w_q);
                @memcpy(w.blocks[b].sacred_attn.w_k, source.blocks[b].sacred_attn.w_k);
                @memcpy(w.blocks[b].sacred_attn.w_v, source.blocks[b].sacred_attn.w_v);
                @memcpy(w.blocks[b].sacred_attn.w_o, source.blocks[b].sacred_attn.w_o);
                @memcpy(w.blocks[b].sacred_attn.rms_gamma, source.blocks[b].sacred_attn.rms_gamma);
            }
        }
    }

    /// Process batch in parallel: each worker handles batch_size/N_WORKERS samples.
    /// Worker 0 (main thread) handles remainder samples.
    /// Returns total loss (sum, not averaged — caller divides by batch_size).
    /// Spawns N_WORKERS-1 threads; main thread processes worker 0.
    pub fn processBatch(
        self: *Self,
        batch: *const data_mod.Batch,
        batch_size: usize,
    ) f32 {
        // If batch is smaller than workers, use fewer workers
        const active_workers = @min(N_WORKERS, batch_size);
        const samples_per_worker = batch_size / active_workers;
        const remainder = batch_size % active_workers;

        // Worker results (loss per worker)
        var worker_losses: [N_WORKERS]f32 = [_]f32{0.0} ** N_WORKERS;

        // Spawn active_workers - 1 threads for workers 1..N
        // Each gets samples_per_worker samples; worker 0 gets remainder extras
        var threads: [N_WORKERS - 1]std.Thread = undefined;
        var spawned: usize = 0;
        for (1..active_workers) |w| {
            const start = remainder + w * samples_per_worker;
            threads[w - 1] = std.Thread.spawn(.{}, workerFn, .{
                &self.workers[w],
                batch,
                start,
                samples_per_worker,
                &worker_losses[w],
                self.allocator,
            }) catch continue;
            spawned += 1;
        }

        // Main thread processes worker 0 (+ remainder samples)
        workerFn(
            &self.workers[0],
            batch,
            0,
            samples_per_worker + remainder,
            &worker_losses[0],
            self.allocator,
        );

        // Join spawned threads
        for (threads[0..spawned]) |t| t.join();

        // Sum losses
        var total_loss: f32 = 0.0;
        for (worker_losses[0..active_workers]) |l| total_loss += l;
        return total_loss;
    }

    /// Sum gradients from all workers into target model's grad buffers.
    /// Target model grads should be zeroed before calling this.
    pub fn accumulateGradsInto(self: *Self, target: *model_mod.HSLM) void {
        for (&self.workers) |*w| {
            // Output projection grads
            addSlice(target.grad_output_shadow, w.grad_output_shadow);
            addSlice(target.grad_output_bias, w.grad_output_bias);

            // Per-block grads
            for (0..target.blocks.len) |b| {
                // TNN grads
                addSlice(target.blocks[b].tnn.grad_shadow_up, w.blocks[b].tnn.grad_shadow_up);
                addSlice(target.blocks[b].tnn.grad_shadow_down, w.blocks[b].tnn.grad_shadow_down);
                addSlice(target.blocks[b].tnn.grad_bias_up, w.blocks[b].tnn.grad_bias_up);
                addSlice(target.blocks[b].tnn.grad_bias_down, w.blocks[b].tnn.grad_bias_down);

                // Sacred Attention grads
                addSlice(target.blocks[b].sacred_attn.grad_q, w.blocks[b].sacred_attn.grad_q);
                addSlice(target.blocks[b].sacred_attn.grad_k, w.blocks[b].sacred_attn.grad_k);
                addSlice(target.blocks[b].sacred_attn.grad_v, w.blocks[b].sacred_attn.grad_v);
                addSlice(target.blocks[b].sacred_attn.grad_o, w.blocks[b].sacred_attn.grad_o);
                addSlice(target.blocks[b].sacred_attn.grad_rms_gamma, w.blocks[b].sacred_attn.grad_rms_gamma);
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// WORKER FUNCTION (runs on thread pool)
// ═══════════════════════════════════════════════════════════════════════════════

fn workerFn(
    worker: *model_mod.HSLM,
    batch: *const data_mod.Batch,
    start_idx: usize,
    num_samples: usize,
    loss_out: *f32,
    allocator: std.mem.Allocator,
) void {
    // Zero worker grads before accumulating
    worker.zeroGrad();

    var total_loss: f32 = 0.0;
    for (start_idx..start_idx + num_samples) |b| {
        const input = batch.getInput(b);
        const target = batch.getTarget(b);
        const seq_len = @min(input.len, CONTEXT_LEN);

        // Reset KV cache before each new sequence (mandatory — different sequences!)
        for (&worker.blocks) |*block| {
            block.sacred_attn.resetCache();
        }

        // Forward with caching
        var logits: [VOCAB_SIZE]f32 = undefined;
        worker.forwardTrain(input[0..seq_len], &logits);

        // Compute loss + backward
        var grad_buf: [VOCAB_SIZE]f32 = [_]f32{0.0} ** VOCAB_SIZE;
        var logits_tensor = autograd.Tensor{
            .data = &logits,
            .grad = &grad_buf,
            .rows = 1,
            .cols = VOCAB_SIZE,
            .requires_grad = false,
            .allocator = allocator,
        };
        const loss = autograd.forwardCrossEntropy(&logits_tensor, target[seq_len - 1 ..]);
        autograd.backwardCrossEntropy(&logits_tensor, target[seq_len - 1 ..]);
        worker.backward(&grad_buf);

        total_loss += loss;
    }
    loss_out.* = total_loss;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Element-wise add: dst[i] += src[i]
fn addSlice(dst: []f32, src: []const f32) void {
    for (dst, src) |*d, s| {
        d.* += s;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "parallel worker init/deinit" {
    const allocator = std.testing.allocator;
    var par = try ParallelTrainer.init(allocator);
    defer par.deinit();

    // Verify workers are initialized
    for (par.workers) |w| {
        try std.testing.expect(w.is_worker);
        try std.testing.expect(w.output_shadow.len == 0); // No shadow weights
    }
}

test "parallel weight sync copies correctly" {
    const allocator = std.testing.allocator;

    // Create master model
    var master = try model_mod.HSLM.init(allocator);
    defer master.deinit();

    var par = try ParallelTrainer.init(allocator);
    defer par.deinit();

    // Sync weights
    par.syncWeights(&master);

    // Verify ternary weights match
    for (0..EMBED_DIM * VOCAB_SIZE) |i| {
        try std.testing.expect(par.workers[0].output_weights[i] == master.output_weights[i]);
    }
    // Verify bias matches
    for (0..VOCAB_SIZE) |i| {
        try std.testing.expect(par.workers[0].output_bias[i] == master.output_bias[i]);
    }
    // Verify block weights
    for (0..master.blocks.len) |b| {
        try std.testing.expect(par.workers[0].blocks[b].tnn.weights_up[0] == master.blocks[b].tnn.weights_up[0]);
        try std.testing.expect(par.workers[0].blocks[b].sacred_attn.w_q[0] == master.blocks[b].sacred_attn.w_q[0]);
    }
}

test "parallel produces loss" {
    const allocator = std.testing.allocator;

    var master = try model_mod.HSLM.init(allocator);
    defer master.deinit();

    var ds = try data_mod.Dataset.init(allocator, CONTEXT_LEN);
    defer ds.deinit();
    try ds.addText("The quick brown fox jumps over the lazy dog many many times today and runs.");
    try ds.addText("A little cat sat on a warm mat by the door of the old house near the park.");
    try ds.addText("The sun was shining bright and birds were singing in the tall green leafy trees.");

    var par = try ParallelTrainer.init(allocator);
    defer par.deinit();

    // Sync weights from master
    par.syncWeights(&master);

    // Create batch of N_WORKERS samples
    const batch_size = N_WORKERS;
    var batch = try data_mod.Batch.init(allocator, batch_size, CONTEXT_LEN);
    defer batch.deinit();
    ds.nextBatch(&batch);

    // Process in parallel
    const total_loss = par.processBatch(&batch, batch_size);

    // Loss should be finite and positive
    try std.testing.expect(!std.math.isNan(total_loss));
    try std.testing.expect(!std.math.isInf(total_loss));
    try std.testing.expect(total_loss > 0.0);
}

test "parallel gradient accumulation" {
    const allocator = std.testing.allocator;

    var master = try model_mod.HSLM.init(allocator);
    defer master.deinit();

    var ds = try data_mod.Dataset.init(allocator, CONTEXT_LEN);
    defer ds.deinit();
    try ds.addText("The quick brown fox jumps over the lazy dog many many times today and runs.");
    try ds.addText("A little cat sat on a warm mat by the door of the old house near the park.");
    try ds.addText("The sun was shining bright and birds were singing in the tall green leafy trees.");

    var par = try ParallelTrainer.init(allocator);
    defer par.deinit();

    par.syncWeights(&master);

    const batch_size = N_WORKERS;
    var batch = try data_mod.Batch.init(allocator, batch_size, CONTEXT_LEN);
    defer batch.deinit();
    ds.nextBatch(&batch);

    _ = par.processBatch(&batch, batch_size);

    // Accumulate into master
    master.zeroGrad();
    par.accumulateGradsInto(&master);

    // Master should have non-zero gradients
    var any_nonzero = false;
    for (master.grad_output_shadow) |g| {
        if (g != 0.0) {
            any_nonzero = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero);

    // Block grads should also be non-zero
    any_nonzero = false;
    for (master.blocks[0].tnn.grad_shadow_up) |g| {
        if (g != 0.0) {
            any_nonzero = true;
            break;
        }
    }
    try std.testing.expect(any_nonzero);
}
