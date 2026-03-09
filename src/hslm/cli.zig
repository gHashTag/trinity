// HSLM — Training CLI
// Usage: zig-out/bin/hslm-train [options]
//
// Architecture: TNN (System 1) + VSA (System 2) + Sacred Attention, ~1.95M ternary params
// Training: Autograd with STE quantization, AdamW optimizer
//
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const constants = @import("constants.zig");
const model_mod = @import("model.zig");
const data_mod = @import("data.zig");
const trainer_mod = @import("trainer.zig");
const bench_mod = @import("bench.zig");
const tokenizer_mod = @import("tokenizer.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse arguments
    var data_path: ?[]const u8 = null;
    var steps: u32 = 50000;
    var lr: f32 = 3e-4;
    var batch_size: usize = 9;
    var checkpoint_dir: []const u8 = "data/checkpoints";
    var max_lines: usize = 100000;
    var mode: enum { train, bench, generate } = .train;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--data") and i + 1 < args.len) {
            i += 1;
            data_path = args[i];
        } else if (std.mem.eql(u8, arg, "--steps") and i + 1 < args.len) {
            i += 1;
            steps = std.fmt.parseInt(u32, args[i], 10) catch 50000;
        } else if (std.mem.eql(u8, arg, "--lr") and i + 1 < args.len) {
            i += 1;
            lr = std.fmt.parseFloat(f32, args[i]) catch 3e-4;
        } else if (std.mem.eql(u8, arg, "--batch") and i + 1 < args.len) {
            i += 1;
            batch_size = std.fmt.parseInt(usize, args[i], 10) catch 9;
        } else if (std.mem.eql(u8, arg, "--checkpoint-dir") and i + 1 < args.len) {
            i += 1;
            checkpoint_dir = args[i];
        } else if (std.mem.eql(u8, arg, "--max-lines") and i + 1 < args.len) {
            i += 1;
            max_lines = std.fmt.parseInt(usize, args[i], 10) catch 100000;
        } else if (std.mem.eql(u8, arg, "bench")) {
            mode = .bench;
        } else if (std.mem.eql(u8, arg, "generate")) {
            mode = .generate;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            return;
        }
    }

    switch (mode) {
        .bench => try runBenchmarks(allocator),
        .generate => try runGenerate(allocator),
        .train => try runTrain(allocator, data_path, steps, lr, batch_size, checkpoint_dir, max_lines),
    }
}

fn printUsage() void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    stdout.print(
        \\HSLM Training CLI — Hybrid Symbolic Language Model
        \\
        \\Usage:
        \\  hslm-train [options]           Train HSLM on text data
        \\  hslm-train bench               Run performance benchmarks
        \\  hslm-train generate            Generate text samples
        \\
        \\Options:
        \\  --data <path>          Path to training text file (one story per line)
        \\  --steps <n>            Total training steps (default: 50000)
        \\  --lr <float>           Learning rate (default: 3e-4)
        \\  --batch <n>            Batch size (default: 9)
        \\  --max-lines <n>        Max lines to load from file (default: 100000)
        \\  --checkpoint-dir <dir> Checkpoint directory (default: data/checkpoints)
        \\  --help, -h             Show this help
        \\
        \\Examples:
        \\  hslm-train --data data/tinystories/train_100k.txt --steps 50000
        \\  hslm-train bench
        \\  hslm-train generate
        \\
    , .{}) catch {};
}

fn runTrain(
    allocator: std.mem.Allocator,
    data_path: ?[]const u8,
    total_steps: u32,
    lr: f32,
    batch_size: usize,
    checkpoint_dir: []const u8,
    max_lines: usize,
) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print(
        \\
        \\================================================================
        \\  HSLM Training — Hybrid Symbolic Language Model
        \\  ~1.95M ternary parameters, ~390KB
        \\  Autograd + STE quantization + AdamW
        \\================================================================
        \\
    , .{});

    // Initialize model
    try stdout.print("[1/4] Initializing model...\n", .{});
    var model = try model_mod.HSLM.init(allocator);
    defer model.deinit();

    const mem_kb = bench_mod.memoryUsage();
    try stdout.print("       Params: {d}, Memory: {d}KB\n", .{ model.paramCount(), mem_kb });

    // Load data
    try stdout.print("[2/4] Loading training data...\n", .{});
    var dataset = try data_mod.Dataset.init(allocator, constants.CONTEXT_LEN);
    defer dataset.deinit();

    if (data_path) |path| {
        try stdout.print("       File: {s}\n", .{path});
        const lines = try dataset.loadTextFile(path, max_lines);
        try stdout.print("       Loaded {d} stories, {d} tokens\n", .{ lines, dataset.totalTokens() });
    } else {
        // Demo data for testing
        try stdout.print("       [WARNING] No --data provided, using demo text\n", .{});
        const demo_texts = [_][]const u8{
            "Once upon a time there was a little cat. The cat was very happy. It played in the garden all day long.",
            "There was a big dog named Max. Max liked to run in the park. He would chase the ball and bring it back.",
            "A little girl had a red balloon. She held it tight but the wind blew it away. She was sad at first.",
            "The sun was shining bright. Birds were singing in the trees. It was a beautiful day to play outside.",
            "Tom had a new toy car. It was blue and very fast. He raced it around the house with his friend Sam.",
        };
        for (demo_texts) |text| {
            try dataset.addText(text);
        }
        try stdout.print("       Demo: {d} tokens\n", .{dataset.totalTokens()});
    }

    if (dataset.totalTokens() < constants.CONTEXT_LEN + 1) {
        try stdout.print("[ERROR] Not enough data to train ({d} tokens, need > {d})\n", .{ dataset.totalTokens(), constants.CONTEXT_LEN + 1 });
        return;
    }

    // Create checkpoint directory
    std.fs.cwd().makePath(checkpoint_dir) catch {};

    // Initialize trainer
    try stdout.print("[3/4] Initializing trainer...\n", .{});
    const config = trainer_mod.TrainConfig{
        .lr = lr,
        .total_steps = total_steps,
        .batch_size = batch_size,
        .checkpoint_every = 5000,
        .log_every = 100,
    };
    try stdout.print("       LR: {d:.6}, Steps: {d}, Batch: {d}\n", .{ config.lr, config.total_steps, config.batch_size });

    // Weight decay schedule: disable at 50% of training
    const wd_disable_step = total_steps / 2;
    const initial_wd = config.weight_decay;

    // Consciousness threshold warmup
    const consciousness_warmup_steps: u32 = 10000;
    const initial_threshold: f64 = 0.15;
    const final_threshold: f64 = constants.PHI_INV;

    const EMBED_DIM = constants.EMBED_DIM;
    try stdout.print("       WD: {d:.3} (cosine, disable at 50%)\n", .{initial_wd});
    try stdout.print("       Consciousness: adaptive threshold {d:.2} -> phi^-1 (warmup {d}K steps)\n", .{ initial_threshold, consciousness_warmup_steps / 1000 });
    const tnn_per_block = EMBED_DIM * constants.HIDDEN_DIM * 2 + constants.HIDDEN_DIM + EMBED_DIM;
    const attn_per_block = EMBED_DIM * EMBED_DIM * 4 + EMBED_DIM;
    const total_trainable = VOCAB_SIZE * EMBED_DIM + VOCAB_SIZE + 3 * (tnn_per_block + attn_per_block);
    try stdout.print("       Full STE backprop: {d} trainable params (100%%)\n", .{total_trainable});

    var trainer = try trainer_mod.FullTrainer.init(allocator, &model, &dataset, config);
    defer trainer.deinit();

    // Train
    try stdout.print("[4/4] Training...\n\n", .{});
    try stdout.print("Step     | Loss     | AvgL10   | PPL      | LR       | C-Ratio  | Tok/s\n", .{});
    try stdout.print("---------|----------|----------|----------|----------|----------|--------\n", .{});

    var batch = try data_mod.Batch.init(allocator, batch_size, constants.CONTEXT_LEN);
    defer batch.deinit();

    // Running average loss (window=10)
    var loss_ring: [10]f32 = .{0} ** 10;
    var loss_ring_idx: usize = 0;
    var loss_ring_count: usize = 0;

    const train_start = std.time.nanoTimestamp();
    var step_tokens: u64 = 0;

    while (trainer.metrics.step < total_steps) {
        dataset.nextBatch(&batch);

        // Accumulate gradients over batch
        trainer.model.zeroGrad();
        var batch_loss: f32 = 0.0;
        for (0..batch_size) |b| {
            batch_loss += trainer.accumulateGrad(batch.getInput(b), batch.getTarget(b));
            step_tokens += constants.CONTEXT_LEN;
        }
        batch_loss /= @as(f32, @floatFromInt(batch_size));
        trainer.metrics.record(batch_loss);
        // Update running average ring buffer
        loss_ring[loss_ring_idx] = batch_loss;
        loss_ring_idx = (loss_ring_idx + 1) % 10;
        if (loss_ring_count < 10) loss_ring_count += 1;
        // Apply accumulated gradients
        trainer.optimizerStep();

        // Weight decay schedule
        if (trainer.metrics.step > wd_disable_step) {
            trainer.optimizer.weight_decay = 0.0;
        } else {
            const wd_progress = @as(f32, @floatFromInt(trainer.metrics.step)) / @as(f32, @floatFromInt(wd_disable_step));
            const wd_cosine = (1.0 + @cos(std.math.pi * wd_progress)) / 2.0;
            trainer.optimizer.weight_decay = initial_wd * wd_cosine;
        }

        // Consciousness threshold warmup
        if (trainer.metrics.step < consciousness_warmup_steps) {
            const t_progress = @as(f64, @floatFromInt(trainer.metrics.step)) / @as(f64, @floatFromInt(consciousness_warmup_steps));
            const threshold = initial_threshold + (final_threshold - initial_threshold) * t_progress;
            for (&trainer.model.blocks) |*block| {
                block.gate.threshold = threshold;
            }
        }

        // Log every N steps
        if (trainer.metrics.step % config.log_every == 0) {
            const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - train_start);
            const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
            const tps = @as(f64, @floatFromInt(step_tokens)) / elapsed_s;

            // Compute running average
            var avg_sum: f32 = 0.0;
            for (0..loss_ring_count) |ri| {
                avg_sum += loss_ring[ri];
            }
            const avg_loss_10 = avg_sum / @as(f32, @floatFromInt(loss_ring_count));

            try stdout.print("{d:>8} | {d:>8.4} | {d:>8.4} | {d:>8.2} | {d:>8.6} | {d:>8.4} | {d:>6.0}\n", .{
                trainer.metrics.step,
                trainer.metrics.loss,
                avg_loss_10,
                trainer.metrics.perplexity,
                trainer.metrics.lr_current,
                trainer.metrics.consciousness_ratio,
                tps,
            });
        }

        // Checkpoint every N steps
        if (trainer.metrics.step % config.checkpoint_every == 0) {
            var path_buf: [256]u8 = undefined;
            const ckpt_path = std.fmt.bufPrint(&path_buf, "{s}/hslm_step_{d}.bin", .{ checkpoint_dir, trainer.metrics.step }) catch "checkpoint.bin";
            trainer_mod.saveCheckpoint(&model, trainer.metrics.step, trainer.metrics.loss, ckpt_path) catch |err| {
                try stdout.print("[WARN] Checkpoint failed: {}\n", .{err});
            };
            try stdout.print("[CKPT] Saved: {s}\n", .{ckpt_path});
        }

        // Milestone text generation
        if (trainer.metrics.step == 1000 or trainer.metrics.step == 2000 or trainer.metrics.step == 3000) {
            try stdout.print("\n[MILESTONE step {d}] Generated text:\n", .{trainer.metrics.step});
            try generateSample(allocator, &model);
            try stdout.print("\n", .{});
        }
    }

    // Final summary
    const total_ns: u64 = @intCast(std.time.nanoTimestamp() - train_start);
    const total_s = @as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0;

    try stdout.print(
        \\
        \\================================================================
        \\  Training Complete!
        \\================================================================
        \\  Steps:       {d}
        \\  Final loss:  {d:.4}
        \\  Perplexity:  {d:.2}
        \\  Best loss:   {d:.4}
        \\  Avg loss:    {d:.4}
        \\  Time:        {d:.1}s
        \\  Throughput:  {d:.0} tok/s
        \\  C-Ratio:     {d:.4}
        \\================================================================
        \\
    , .{
        trainer.metrics.step,
        trainer.metrics.loss,
        trainer.metrics.perplexity,
        trainer.metrics.best_loss,
        trainer.metrics.avgLoss(),
        total_s,
        @as(f64, @floatFromInt(step_tokens)) / total_s,
        trainer.metrics.consciousness_ratio,
    });

    // Save final checkpoint
    trainer_mod.saveCheckpoint(&model, trainer.metrics.step, trainer.metrics.loss, "data/checkpoints/hslm_final.bin") catch |err| {
        try stdout.print("[WARN] Final checkpoint failed: {}\n", .{err});
    };

    // Generate sample
    try stdout.print("\n[SAMPLE] Generated text:\n", .{});
    try generateSample(allocator, &model);
}

fn runBenchmarks(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print(
        \\
        \\================================================================
        \\  HSLM Performance Benchmarks
        \\================================================================
        \\
    , .{});

    const iterations: usize = 100;

    // Ternary matmul — scalar vs SIMD
    const matmul_scalar = bench_mod.benchTernaryMatmul(iterations);
    try stdout.print("Ternary MatMul (scalar): {d:.2} ops/s, {d:.1}us latency\n", .{
        matmul_scalar.ops_per_sec, matmul_scalar.latency_us,
    });

    const matmul_simd = bench_mod.benchTernaryMatmulSimd(iterations);
    try stdout.print("Ternary MatMul (SIMD):   {d:.2} ops/s, {d:.1}us latency\n", .{
        matmul_simd.ops_per_sec, matmul_simd.latency_us,
    });

    const speedup = matmul_scalar.latency_us / matmul_simd.latency_us;
    try stdout.print("SIMD Speedup:            {d:.2}x\n", .{speedup});

    // VSA attention
    const attn = bench_mod.benchVSAAttention(iterations);
    try stdout.print("VSA Attention:   {d:.2} sims/s, {d:.1}us latency, {d}KB\n", .{
        attn.ops_per_sec, attn.latency_us, attn.memory_kb,
    });

    // Tokenizer
    const tok = bench_mod.benchTokenizer(allocator, iterations);
    try stdout.print("Tokenizer:       {d:.2} tok/s, {d:.1}us latency\n", .{
        tok.ops_per_sec, tok.latency_us,
    });

    // Memory
    const mem = bench_mod.memoryUsage();
    try stdout.print("\nMemory:          {d}KB ({d:.2}MB)\n", .{
        mem, @as(f64, @floatFromInt(mem)) / 1024.0,
    });

    // Comparison
    try stdout.print(
        \\
        \\Model Comparison:
        \\  Model                | Memory   | Params
        \\  ---------------------|----------|----------
    , .{});

    const rows = bench_mod.compareWithBitNet();
    for (rows) |row| {
        try stdout.print("  {s:<20} | {d:>6}KB | {d:>8}\n", .{
            row.model_name, row.memory_kb, row.params,
        });
    }

    try stdout.print("\n", .{});
}

fn runGenerate(allocator: std.mem.Allocator) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n[INIT] Loading HSLM model...\n", .{});
    var model = try model_mod.HSLM.init(allocator);
    defer model.deinit();

    try stdout.print("[GEN] Generating text samples:\n\n", .{});

    try generateSample(allocator, &model);
}

fn generateSample(allocator: std.mem.Allocator, model: *model_mod.HSLM) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    var tok = try tokenizer_mod.Tokenizer.init(allocator);
    defer tok.deinit();

    // Seed prompts
    const prompts = [_][]const u8{
        "Once upon a time",
        "The little cat",
        "A big dog",
    };

    for (prompts) |prompt| {
        var tokens: [256]u16 = undefined;
        const n = tok.encode(prompt, &tokens);

        // Generate 50 tokens
        var gen_len = n;
        for (0..50) |_| {
            if (gen_len >= 255) break;
            const next = model.generate(tokens[0..gen_len]);
            tokens[gen_len] = next;
            gen_len += 1;
            // Stop at EOS
            if (next == 2) break;
        }

        var decoded: [1024]u8 = undefined;
        const m = tok.decode(tokens[0..gen_len], &decoded);
        try stdout.print("  > {s}\n", .{decoded[0..m]});
    }
}

test "cli compiles" {
    // Verify imports resolve
    _ = model_mod.HSLM;
    _ = trainer_mod.FullTrainer;
    _ = bench_mod.BenchResult;
}
