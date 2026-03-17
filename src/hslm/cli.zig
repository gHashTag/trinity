// @origin(spec:cli.tri) @regen(manual-impl)
// @origin(manual) @regen(pending)
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
const ste_mod = @import("ste.zig");
const parallel_mod = @import("parallel.zig");
const bench_mod = @import("bench.zig");
const tokenizer_mod = @import("tokenizer.zig");
const autograd = @import("autograd.zig");
const tjepa_mod = @import("tjepa.zig");
const tjepa_trainer_mod = @import("tjepa_trainer.zig");
const mse_loss_mod = @import("mse_loss.zig");
const nca_mod = @import("nca.zig");

const VOCAB_SIZE = constants.VOCAB_SIZE;
const EMBED_DIM_CONST = constants.EMBED_DIM;
const CONTEXT_LEN_CONST = constants.CONTEXT_LEN;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Parse arguments
    var data_path: ?[]const u8 = null;
    var steps: u32 = 300000;
    var lr: f32 = 3e-4;
    var lr_min: f32 = 1e-6;
    var batch_size: usize = 64;
    var checkpoint_dir: []const u8 = "data/checkpoints";
    var max_lines: usize = 100000;
    var warmup_steps: u32 = 5000;
    var mode: enum { train, bench, generate } = .train;
    var checkpoint_path: ?[]const u8 = null;
    var resume_path: ?[]const u8 = null;
    var weight_decay: f32 = 0.1;
    var dropout: f32 = 0.0;
    var seed_offset: u64 = 0;
    var ste_mode: ste_mod.SteMode = .none;
    var ste_threshold: f32 = 0.5;
    var ste_warmup: u32 = 10000;
    var optimizer_type: trainer_mod.OptimizerType = .adamw;
    var grad_accum: usize = 1;
    var context_len: usize = constants.CONTEXT_LEN;
    var num_blocks: usize = constants.DEFAULT_BLOCKS;
    var lr_schedule: trainer_mod.LrScheduleType = .sacred;
    var label_smoothing_val: f32 = 0.1;
    var restart_period: u32 = 25000;
    var restart_mult: f32 = 1.0;
    var lamb_clamp: f32 = 10.0;
    var stable_ratio: f32 = 0.7;

    // Training objective
    var objective: enum { ntp, jepa, hybrid, nca_ntp, nca_jepa_ntp, nca_jepa_ntp_v2 } = .ntp;
    var nca_steps: u32 = 15000;
    var nca_grid: u8 = 9;
    var nca_states: u8 = 9;
    var nca_rollout: u16 = 128;
    var nca_entropy_min: f32 = 1.5;
    var nca_entropy_max: f32 = 2.8;
    var jepa_steps: u32 = 0; // 0 = auto (half of total for hybrid, 40K for nca-jepa-ntp)
    var ema_decay_start: f32 = 0.996;
    var ema_decay_end: f32 = 1.0;
    var mask_ratio: f32 = 0.3;
    var predictor_lr_mult: f32 = 2.0;
    var log_every: u32 = 100;

    // Ternary architecture flags
    var ternary_grads: bool = false;
    var adaptive_sparsity_flag: bool = false;
    var ternary_schedule_flag: bool = false;
    var full_ternary: bool = false;
    var init_zero: bool = false;

    // Data sharding (T10)
    var data_shard: u32 = 0;
    var num_shards: u32 = 1;
    var total_lines: usize = 15_600_056; // default TinyStories, override via --total-lines

    // Validation split (P1)
    var val_split: f32 = 0.0; // 0 = disabled, 0.1 = 10% held out

    // Gradient clipping (spike prevention)
    var grad_clip_val: f32 = 1.0;

    // Inference / eval args
    var eval_data_path: ?[]const u8 = null;
    var eval_lines: usize = 1000;
    var temperature: f32 = 0.8;
    var top_k: usize = 27;
    var rep_penalty: f32 = 1.2;
    var prompt: ?[]const u8 = null;
    var max_gen_tokens: usize = 200;

    // Early kill thresholds (EXP-025: relaxed defaults — 72/72 W7 runs killed by aggressive thresholds)
    var kill_ppl_10k: f32 = 500.0;
    var kill_ppl_30k: f32 = 200.0;
    var kill_ppl_60k: f32 = 100.0;
    var kill_ppl_80k: f32 = 50.0;

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
        } else if (std.mem.eql(u8, arg, "--lr-min") and i + 1 < args.len) {
            i += 1;
            lr_min = std.fmt.parseFloat(f32, args[i]) catch 1e-6;
        } else if (std.mem.eql(u8, arg, "--batch") and i + 1 < args.len) {
            i += 1;
            batch_size = std.fmt.parseInt(usize, args[i], 10) catch 64;
        } else if (std.mem.eql(u8, arg, "--checkpoint-dir") and i + 1 < args.len) {
            i += 1;
            checkpoint_dir = args[i];
        } else if (std.mem.eql(u8, arg, "--checkpoint") and i + 1 < args.len) {
            i += 1;
            checkpoint_path = args[i];
        } else if (std.mem.eql(u8, arg, "--max-lines") and i + 1 < args.len) {
            i += 1;
            max_lines = std.fmt.parseInt(usize, args[i], 10) catch 100000;
        } else if (std.mem.eql(u8, arg, "--warmup") and i + 1 < args.len) {
            i += 1;
            warmup_steps = std.fmt.parseInt(u32, args[i], 10) catch 500;
        } else if (std.mem.eql(u8, arg, "--resume") and i + 1 < args.len) {
            i += 1;
            resume_path = args[i];
        } else if (std.mem.eql(u8, arg, "--wd") and i + 1 < args.len) {
            i += 1;
            weight_decay = std.fmt.parseFloat(f32, args[i]) catch 0.1;
        } else if (std.mem.eql(u8, arg, "--dropout") and i + 1 < args.len) {
            i += 1;
            dropout = std.fmt.parseFloat(f32, args[i]) catch 0.0;
        } else if (std.mem.eql(u8, arg, "--seed") and i + 1 < args.len) {
            i += 1;
            seed_offset = std.fmt.parseInt(u64, args[i], 10) catch 0;
        } else if (std.mem.eql(u8, arg, "--ste") and i + 1 < args.len) {
            i += 1;
            const mode_str = args[i];
            if (std.mem.eql(u8, mode_str, "vanilla")) {
                ste_mode = .vanilla;
            } else if (std.mem.eql(u8, mode_str, "twn")) {
                ste_mode = .twn;
            } else if (std.mem.eql(u8, mode_str, "progressive")) {
                ste_mode = .progressive;
            } else {
                ste_mode = .none;
            }
        } else if (std.mem.eql(u8, arg, "--ste-threshold") and i + 1 < args.len) {
            i += 1;
            ste_threshold = std.fmt.parseFloat(f32, args[i]) catch 0.5;
        } else if (std.mem.eql(u8, arg, "--ste-warmup") and i + 1 < args.len) {
            i += 1;
            ste_warmup = std.fmt.parseInt(u32, args[i], 10) catch 10000;
        } else if (std.mem.eql(u8, arg, "--optimizer") and i + 1 < args.len) {
            i += 1;
            const opt_str = args[i];
            if (std.mem.eql(u8, opt_str, "lamb")) {
                optimizer_type = .lamb;
            } else {
                optimizer_type = .adamw;
            }
        } else if (std.mem.eql(u8, arg, "--grad-accum") and i + 1 < args.len) {
            i += 1;
            grad_accum = std.fmt.parseInt(usize, args[i], 10) catch 1;
            if (grad_accum < 1) grad_accum = 1;
        } else if (std.mem.eql(u8, arg, "--context") and i + 1 < args.len) {
            i += 1;
            context_len = std.fmt.parseInt(usize, args[i], 10) catch constants.CONTEXT_LEN;
            if (context_len < 1) context_len = 1;
            if (context_len > constants.CONTEXT_LEN) context_len = constants.CONTEXT_LEN;
        } else if (std.mem.eql(u8, arg, "--blocks") and i + 1 < args.len) {
            i += 1;
            num_blocks = std.fmt.parseInt(usize, args[i], 10) catch constants.DEFAULT_BLOCKS;
        } else if (std.mem.eql(u8, arg, "--lr-schedule") and i + 1 < args.len) {
            i += 1;
            const sched_str = args[i];
            if (std.mem.eql(u8, sched_str, "cosine")) {
                lr_schedule = .cosine;
            } else if (std.mem.eql(u8, sched_str, "cosine-restarts")) {
                lr_schedule = .cosine_restarts;
            } else if (std.mem.eql(u8, sched_str, "wsd")) {
                lr_schedule = .wsd;
            } else if (std.mem.eql(u8, sched_str, "d2z")) {
                lr_schedule = .d2z;
            } else if (std.mem.eql(u8, sched_str, "phi-restart") or std.mem.eql(u8, sched_str, "phi_restart")) {
                lr_schedule = .phi_restart;
            } else {
                lr_schedule = .sacred;
            }
        } else if (std.mem.eql(u8, arg, "--label-smoothing") and i + 1 < args.len) {
            i += 1;
            label_smoothing_val = std.fmt.parseFloat(f32, args[i]) catch 0.1;
        } else if (std.mem.eql(u8, arg, "--restart-period") and i + 1 < args.len) {
            i += 1;
            restart_period = std.fmt.parseInt(u32, args[i], 10) catch 25000;
        } else if (std.mem.eql(u8, arg, "--restart-mult") and i + 1 < args.len) {
            i += 1;
            restart_mult = std.fmt.parseFloat(f32, args[i]) catch 1.0;
        } else if (std.mem.eql(u8, arg, "--lamb-clamp") and i + 1 < args.len) {
            i += 1;
            lamb_clamp = std.fmt.parseFloat(f32, args[i]) catch 10.0;
        } else if (std.mem.eql(u8, arg, "--stable-ratio") and i + 1 < args.len) {
            i += 1;
            stable_ratio = std.fmt.parseFloat(f32, args[i]) catch 0.7;
        } else if (std.mem.eql(u8, arg, "--ternary-grads")) {
            ternary_grads = true;
        } else if (std.mem.eql(u8, arg, "--adaptive-sparsity")) {
            adaptive_sparsity_flag = true;
        } else if (std.mem.eql(u8, arg, "--ternary-schedule")) {
            ternary_schedule_flag = true;
        } else if (std.mem.eql(u8, arg, "--full-ternary")) {
            full_ternary = true;
        } else if (std.mem.eql(u8, arg, "--init-zero")) {
            init_zero = true;
        } else if (std.mem.eql(u8, arg, "--data-shard") and i + 1 < args.len) {
            i += 1;
            data_shard = std.fmt.parseInt(u32, args[i], 10) catch 0;
        } else if (std.mem.eql(u8, arg, "--num-shards") and i + 1 < args.len) {
            i += 1;
            num_shards = std.fmt.parseInt(u32, args[i], 10) catch 1;
            if (num_shards < 1) num_shards = 1;
        } else if (std.mem.eql(u8, arg, "--total-lines") and i + 1 < args.len) {
            i += 1;
            total_lines = std.fmt.parseInt(usize, args[i], 10) catch 15_600_056;
        } else if (std.mem.eql(u8, arg, "--val-split") and i + 1 < args.len) {
            i += 1;
            val_split = std.fmt.parseFloat(f32, args[i]) catch 0.0;
        } else if (std.mem.eql(u8, arg, "--grad-clip") and i + 1 < args.len) {
            i += 1;
            grad_clip_val = std.fmt.parseFloat(f32, args[i]) catch 1.0;
        } else if (std.mem.eql(u8, arg, "--kill-ppl-10k") and i + 1 < args.len) {
            i += 1;
            kill_ppl_10k = std.fmt.parseFloat(f32, args[i]) catch 500.0;
        } else if (std.mem.eql(u8, arg, "--kill-ppl-30k") and i + 1 < args.len) {
            i += 1;
            kill_ppl_30k = std.fmt.parseFloat(f32, args[i]) catch 200.0;
        } else if (std.mem.eql(u8, arg, "--kill-ppl-60k") and i + 1 < args.len) {
            i += 1;
            kill_ppl_60k = std.fmt.parseFloat(f32, args[i]) catch 100.0;
        } else if (std.mem.eql(u8, arg, "--kill-ppl-80k") and i + 1 < args.len) {
            i += 1;
            kill_ppl_80k = std.fmt.parseFloat(f32, args[i]) catch 50.0;
        } else if (std.mem.eql(u8, arg, "--objective") and i + 1 < args.len) {
            i += 1;
            const obj_str = args[i];
            if (std.mem.eql(u8, obj_str, "jepa")) {
                objective = .jepa;
            } else if (std.mem.eql(u8, obj_str, "hybrid")) {
                objective = .hybrid;
            } else if (std.mem.eql(u8, obj_str, "nca-ntp")) {
                objective = .nca_ntp;
            } else if (std.mem.eql(u8, obj_str, "nca-jepa-ntp")) {
                objective = .nca_jepa_ntp;
            } else if (std.mem.eql(u8, obj_str, "nca-jepa-ntp-v2")) {
                objective = .nca_jepa_ntp_v2;
            } else {
                objective = .ntp;
            }
        } else if (std.mem.eql(u8, arg, "--ema-decay-start") and i + 1 < args.len) {
            i += 1;
            ema_decay_start = std.fmt.parseFloat(f32, args[i]) catch 0.996;
        } else if (std.mem.eql(u8, arg, "--ema-decay-end") and i + 1 < args.len) {
            i += 1;
            ema_decay_end = std.fmt.parseFloat(f32, args[i]) catch 1.0;
        } else if (std.mem.eql(u8, arg, "--mask-ratio") and i + 1 < args.len) {
            i += 1;
            mask_ratio = std.fmt.parseFloat(f32, args[i]) catch 0.3;
        } else if (std.mem.eql(u8, arg, "--predictor-lr-mult") and i + 1 < args.len) {
            i += 1;
            predictor_lr_mult = std.fmt.parseFloat(f32, args[i]) catch 2.0;
        } else if (std.mem.eql(u8, arg, "--log-every") and i + 1 < args.len) {
            i += 1;
            log_every = std.fmt.parseInt(u32, args[i], 10) catch 100;
        } else if (std.mem.eql(u8, arg, "--nca-steps") and i + 1 < args.len) {
            i += 1;
            nca_steps = std.fmt.parseInt(u32, args[i], 10) catch 15000;
        } else if (std.mem.eql(u8, arg, "--nca-grid") and i + 1 < args.len) {
            i += 1;
            nca_grid = std.fmt.parseInt(u8, args[i], 10) catch 9;
        } else if (std.mem.eql(u8, arg, "--nca-states") and i + 1 < args.len) {
            i += 1;
            nca_states = std.fmt.parseInt(u8, args[i], 10) catch 9;
        } else if (std.mem.eql(u8, arg, "--nca-rollout") and i + 1 < args.len) {
            i += 1;
            nca_rollout = std.fmt.parseInt(u16, args[i], 10) catch 128;
        } else if (std.mem.eql(u8, arg, "--nca-entropy-min") and i + 1 < args.len) {
            i += 1;
            nca_entropy_min = std.fmt.parseFloat(f32, args[i]) catch 1.5;
        } else if (std.mem.eql(u8, arg, "--nca-entropy-max") and i + 1 < args.len) {
            i += 1;
            nca_entropy_max = std.fmt.parseFloat(f32, args[i]) catch 2.8;
        } else if (std.mem.eql(u8, arg, "--jepa-steps") and i + 1 < args.len) {
            i += 1;
            jepa_steps = std.fmt.parseInt(u32, args[i], 10) catch 0;
        } else if (std.mem.eql(u8, arg, "--eval") and i + 1 < args.len) {
            i += 1;
            eval_data_path = args[i];
        } else if (std.mem.eql(u8, arg, "--eval-lines") and i + 1 < args.len) {
            i += 1;
            eval_lines = std.fmt.parseInt(usize, args[i], 10) catch 1000;
        } else if (std.mem.eql(u8, arg, "--temperature") and i + 1 < args.len) {
            i += 1;
            temperature = std.fmt.parseFloat(f32, args[i]) catch 0.8;
        } else if (std.mem.eql(u8, arg, "--top-k") and i + 1 < args.len) {
            i += 1;
            top_k = std.fmt.parseInt(usize, args[i], 10) catch 27;
        } else if (std.mem.eql(u8, arg, "--rep-penalty") and i + 1 < args.len) {
            i += 1;
            rep_penalty = std.fmt.parseFloat(f32, args[i]) catch 1.2;
        } else if (std.mem.eql(u8, arg, "--prompt") and i + 1 < args.len) {
            i += 1;
            prompt = args[i];
        } else if (std.mem.eql(u8, arg, "--max-tokens") and i + 1 < args.len) {
            i += 1;
            max_gen_tokens = std.fmt.parseInt(usize, args[i], 10) catch 200;
        } else if (std.mem.eql(u8, arg, "bench")) {
            mode = .bench;
        } else if (std.mem.eql(u8, arg, "generate")) {
            mode = .generate;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printUsage();
            return;
        }
    }

    // HSLM_BLOCKS env var fallback (Railway)
    if (num_blocks == constants.DEFAULT_BLOCKS) {
        if (std.posix.getenv("HSLM_BLOCKS")) |env_blocks| {
            num_blocks = std.fmt.parseInt(usize, env_blocks, 10) catch constants.DEFAULT_BLOCKS;
        }
    }

    // Validate block count
    if (!constants.isValidBlockCount(num_blocks)) {
        const stderr = std.fs.File.stderr().deprecatedWriter();
        stderr.print("[FATAL] Invalid --blocks {d}: must be power of 3, max {d} (valid: 1, 3, 9)\n", .{ num_blocks, constants.MAX_BLOCKS }) catch {};
        std.process.exit(1);
    }

    switch (mode) {
        .bench => try runBenchmarks(allocator),
        .generate => try runGenerate(allocator, checkpoint_path, .{
            .eval_data_path = eval_data_path,
            .eval_lines = eval_lines,
            .temperature = temperature,
            .top_k = top_k,
            .rep_penalty = rep_penalty,
            .prompt = prompt,
            .max_gen_tokens = max_gen_tokens,
            .context_len = context_len,
            .num_blocks = num_blocks,
        }),
        .train => switch (objective) {
            .ntp => try runTrain(allocator, data_path, steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, resume_path, weight_decay, dropout, seed_offset, ste_mod.SteConfig{
                .mode = ste_mode,
                .threshold = ste_threshold,
                .warmup_steps = ste_warmup,
            }, optimizer_type, grad_accum, context_len, lr_schedule, label_smoothing_val, restart_period, restart_mult, ternary_grads or full_ternary, adaptive_sparsity_flag or full_ternary, ternary_schedule_flag or full_ternary, lamb_clamp, stable_ratio, init_zero, data_shard, num_shards, total_lines, val_split, grad_clip_val, kill_ppl_10k, kill_ppl_30k, kill_ppl_60k, kill_ppl_80k, num_blocks),
            .jepa => try runJepaTraining(allocator, data_path, steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, resume_path, seed_offset, context_len, grad_clip_val, weight_decay, ema_decay_start, ema_decay_end, mask_ratio, predictor_lr_mult, log_every, init_zero),
            .hybrid => try runHybridTraining(allocator, data_path, steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, resume_path, weight_decay, dropout, seed_offset, ste_mod.SteConfig{
                .mode = ste_mode,
                .threshold = ste_threshold,
                .warmup_steps = ste_warmup,
            }, optimizer_type, grad_accum, context_len, lr_schedule, label_smoothing_val, restart_period, restart_mult, ternary_grads or full_ternary, adaptive_sparsity_flag or full_ternary, ternary_schedule_flag or full_ternary, lamb_clamp, stable_ratio, init_zero, data_shard, num_shards, total_lines, val_split, grad_clip_val, kill_ppl_10k, kill_ppl_30k, kill_ppl_60k, kill_ppl_80k, ema_decay_start, ema_decay_end, mask_ratio, predictor_lr_mult, log_every, num_blocks),
            .nca_ntp => try runNcaNtpTraining(allocator, data_path, steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, resume_path, weight_decay, dropout, seed_offset, ste_mod.SteConfig{
                .mode = ste_mode,
                .threshold = ste_threshold,
                .warmup_steps = ste_warmup,
            }, optimizer_type, grad_accum, context_len, lr_schedule, label_smoothing_val, restart_period, restart_mult, ternary_grads or full_ternary, adaptive_sparsity_flag or full_ternary, ternary_schedule_flag or full_ternary, lamb_clamp, stable_ratio, init_zero, data_shard, num_shards, total_lines, val_split, grad_clip_val, kill_ppl_10k, kill_ppl_30k, kill_ppl_60k, kill_ppl_80k, num_blocks, nca_steps, nca_grid, nca_states, nca_rollout, nca_entropy_min, nca_entropy_max),
            .nca_jepa_ntp => try runNcaJepaNtpTraining(allocator, data_path, steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, resume_path, weight_decay, dropout, seed_offset, ste_mod.SteConfig{
                .mode = ste_mode,
                .threshold = ste_threshold,
                .warmup_steps = ste_warmup,
            }, optimizer_type, grad_accum, context_len, lr_schedule, label_smoothing_val, restart_period, restart_mult, ternary_grads or full_ternary, adaptive_sparsity_flag or full_ternary, ternary_schedule_flag or full_ternary, lamb_clamp, stable_ratio, init_zero, data_shard, num_shards, total_lines, val_split, grad_clip_val, kill_ppl_10k, kill_ppl_30k, kill_ppl_60k, kill_ppl_80k, ema_decay_start, ema_decay_end, mask_ratio, predictor_lr_mult, log_every, num_blocks, nca_steps, nca_grid, nca_states, nca_rollout, nca_entropy_min, nca_entropy_max, if (jepa_steps > 0) jepa_steps else 40000),
            .nca_jepa_ntp_v2 => try runNcaJepaNtpTraining(allocator, data_path, steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, resume_path, weight_decay, dropout, seed_offset, ste_mod.SteConfig{
                .mode = ste_mode,
                .threshold = ste_threshold,
                .warmup_steps = ste_warmup,
            }, optimizer_type, grad_accum, context_len, lr_schedule, label_smoothing_val, restart_period, restart_mult, ternary_grads or full_ternary, adaptive_sparsity_flag or full_ternary, ternary_schedule_flag or full_ternary, lamb_clamp, stable_ratio, init_zero, data_shard, num_shards, total_lines, val_split, grad_clip_val, kill_ppl_10k, kill_ppl_30k, kill_ppl_60k, kill_ppl_80k, ema_decay_start, ema_decay_end, mask_ratio, predictor_lr_mult, log_every, num_blocks, nca_steps, nca_grid, nca_states, nca_rollout, nca_entropy_min, nca_entropy_max, if (jepa_steps > 0) jepa_steps else 20000),
        },
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
        \\  --steps <n>            Total training steps (default: 300000)
        \\  --lr <float>           Peak learning rate (default: 3e-4)
        \\  --lr-min <float>       Minimum learning rate (default: 1e-6)
        \\  --batch <n>            Batch size (default: 64)
        \\  --max-lines <n>        Max lines to load from file (default: 100000)
        \\  --checkpoint-dir <dir> Checkpoint directory (default: data/checkpoints)
        \\  --warmup <n>           Warmup steps (default: 5000)
        \\  --resume <path>        Resume training from checkpoint file
        \\  --wd <float>           Weight decay (default: 0.1)
        \\  --dropout <float>      Dropout rate after attention (default: 0.0)
        \\  --seed <n>             Seed offset for weight init (default: 0)
        \\  --ste <mode>           STE mode: none|vanilla|twn|progressive (default: none)
        \\  --ste-threshold <f>    Vanilla STE threshold (default: 0.5)
        \\  --ste-warmup <n>       Progressive STE warmup steps (default: 10000)
        \\  --optimizer <type>     Optimizer: adamw|lamb (default: adamw)
        \\  --grad-accum <n>       Gradient accumulation steps (default: 1, eff_batch = batch * n)
        \\  --grad-clip <float>    Gradient clipping max norm (default: 1.0, spike prevention)
        \\  --blocks <n>           Number of Trinity blocks: 1, 3, or 9 (default: 3, env: HSLM_BLOCKS)
        \\  --context <n>          Context length (default: 81, max: 81, shorter = faster)
        \\  --lr-schedule <type>   LR schedule: sacred|cosine|cosine-restarts|wsd|phi-restart|d2z (default: sacred)
        \\  --label-smoothing <f>  Label smoothing epsilon (default: 0.1, 0=off)
        \\  --restart-period <n>   Cosine-restarts: initial period (default: 25000)
        \\  --restart-mult <f>     Cosine-restarts: period multiplier (default: 1.0)
        \\  --lamb-clamp <f>       LAMB trust ratio clamp (default: 10.0, lower = safer)
        \\  --stable-ratio <f>     WSD: fraction at peak LR (default: 0.7)
        \\  --ternary-grads        Use TernGrad gradient compression
        \\  --adaptive-sparsity    Use 3-level adaptive sparsity
        \\  --ternary-schedule     Use 3-phase φ-decaying LR schedule
        \\  --full-ternary         Enable all ternary features
        \\  --init-zero            Zero-init all weights (reduces seed variance)
        \\  --data-shard <n>       Shard index for data sharding (default: 0)
        \\  --num-shards <n>       Total number of shards (default: 1 = no sharding)
        \\  --total-lines <n>      Total lines in dataset (default: 15600056)
        \\  --val-split <f>        Validation split ratio (default: 0.0 = off, 0.1 = 10%)
        \\  --kill-ppl-10k <f>    Early kill PPL threshold at 10K steps (default: 500)
        \\  --kill-ppl-30k <f>    Early kill PPL threshold at 30K steps (default: 200)
        \\  --kill-ppl-60k <f>    Early kill PPL threshold at 60K steps (default: 100)
        \\  --kill-ppl-80k <f>    Early kill PPL threshold at 80K steps (default: 50)
        \\  --log-every <n>        Log interval in steps (default: 100)
        \\
        \\T-JEPA Options:
        \\  --objective <type>     Training objective: ntp|jepa|hybrid|nca-ntp|nca-jepa-ntp|nca-jepa-ntp-v2
        \\  --ema-decay-start <f>  JEPA: EMA decay start (default: 0.996)
        \\  --ema-decay-end <f>    JEPA: EMA decay end (default: 1.0)
        \\  --mask-ratio <f>       JEPA: mask ratio (default: 0.3)
        \\  --predictor-lr-mult <f> JEPA: predictor LR multiplier (default: 2.0)
        \\
        \\NCA Pre-Pre-Training Options:
        \\  --nca-steps <n>        NCA stage steps (default: 15000)
        \\  --nca-grid <n>         NCA grid size (default: 9, 9x9=81=CONTEXT_LEN)
        \\  --nca-states <n>       NCA states per cell (default: 9)
        \\  --nca-rollout <n>      NCA rollout steps per trajectory (default: 128)
        \\  --nca-entropy-min <f>  NCA min entropy filter (default: 1.5)
        \\  --nca-entropy-max <f>  NCA max entropy filter (default: 2.8)
        \\  --jepa-steps <n>       JEPA stage steps for nca-jepa-ntp (default: 40000/20000)
        \\
        \\  --help, -h             Show this help
        \\
        \\Examples:
        \\  hslm-train --data data/tinystories/train_100k.txt --steps 50000
        \\  hslm-train bench
        \\  hslm-train generate
        \\
    , .{}) catch |err| {
        std.log.debug("cli: failed to print usage: {}", .{err});
    };
}

fn runTrain(
    allocator: std.mem.Allocator,
    data_path: ?[]const u8,
    total_steps: u32,
    lr: f32,
    lr_min: f32,
    batch_size: usize,
    checkpoint_dir: []const u8,
    max_lines: usize,
    warmup_steps: u32,
    resume_path: ?[]const u8,
    weight_decay_override: f32,
    dropout: f32,
    seed_offset: u64,
    ste_config: ste_mod.SteConfig,
    optimizer_type: trainer_mod.OptimizerType,
    grad_accum: usize,
    context_len: usize,
    lr_schedule: trainer_mod.LrScheduleType,
    label_smoothing_val: f32,
    restart_period: u32,
    restart_mult: f32,
    t_ternary_grads: bool,
    t_adaptive_sparsity: bool,
    t_ternary_schedule: bool,
    lamb_clamp_val: f32,
    stable_ratio_val: f32,
    init_zero_flag: bool,
    data_shard: u32,
    num_shards: u32,
    total_lines: usize,
    val_split: f32,
    grad_clip_val: f32,
    kill_ppl_10k: f32,
    kill_ppl_30k: f32,
    kill_ppl_60k: f32,
    kill_ppl_80k: f32,
    num_blocks_arg: usize,
) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    const model_config = constants.Config{ .num_blocks = num_blocks_arg };

    try stdout.print(
        \\
        \\================================================================
        \\  HSLM Training — Hybrid Symbolic Language Model
        \\  Blocks: {d}, Params: ~{d}K, Memory: ~{d}KB
        \\  Autograd + STE quantization + AdamW
        \\================================================================
        \\
    , .{ num_blocks_arg, model_config.paramCount() / 1000, model_config.memorySizeKB() });

    // Square Attention check
    const head_dim = constants.HEAD_DIM;
    if (context_len != head_dim) {
        try stdout.print("  ⚠ Non-square attention: ctx={d} × head_dim={d} (rank-deficient QKᵀ)\n", .{ context_len, head_dim });
    }

    // Initialize model
    if (init_zero_flag) {
        try stdout.print("[1/4] Initializing model (ZERO init — all weights zeroed, blocks={d})...\n", .{num_blocks_arg});
    } else if (seed_offset > 0) {
        try stdout.print("[1/4] Initializing model (seed offset: {d}, blocks={d})...\n", .{ seed_offset, num_blocks_arg });
    } else {
        try stdout.print("[1/4] Initializing model (blocks={d})...\n", .{num_blocks_arg});
    }
    var model = if (init_zero_flag)
        try model_mod.HSLM.initZeroWithConfig(allocator, model_config)
    else
        try model_mod.HSLM.initWithConfigAndSeed(allocator, model_config, seed_offset);
    defer model.deinit();

    const mem_kb = bench_mod.memoryUsage();
    try stdout.print("       Params: {d}, Memory: {d}KB\n", .{ model.paramCount(), mem_kb });

    var resume_step: u32 = 0;

    // Load data
    try stdout.print("[2/4] Loading training data...\n", .{});
    var dataset = try data_mod.Dataset.init(allocator, context_len);
    defer dataset.deinit();

    if (data_path) |path| {
        try stdout.print("       File: {s}\n", .{path});
        if (num_shards > 1) {
            // Data sharding: load unique shard
            const shard_size = total_lines / num_shards;
            const skip = @as(usize, data_shard) * shard_size;
            const lines = try dataset.loadTextFileShard(path, skip, shard_size);
            try stdout.print("       Shard {d}/{d}: skip={d}, loaded {d} stories, {d} tokens\n", .{
                data_shard, num_shards, skip, lines, dataset.totalTokens(),
            });
        } else {
            const lines = try dataset.loadTextFile(path, max_lines);
            try stdout.print("       Loaded {d} stories, {d} tokens\n", .{ lines, dataset.totalTokens() });
        }
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

    if (dataset.totalTokens() < context_len + 1) {
        try stdout.print("[ERROR] Not enough data to train ({d} tokens, need > {d})\n", .{ dataset.totalTokens(), context_len + 1 });
        return;
    }

    // Hard fail: demo corpus (< 1000 tokens) is useless for real training
    if (data_path == null and dataset.totalTokens() < 1000) {
        try stdout.print("[FATAL] Demo corpus too small ({d} tokens) — this is memorization, not training.\n", .{dataset.totalTokens()});
        try stdout.print("        Use --data <path> for real training data.\n", .{});
        try stdout.print("        Example: hslm-train --data data/tinystories/real_tinystories.txt\n", .{});
        return;
    }

    // Validation split (P1: separate train/val to detect overfitting)
    var val_dataset: ?data_mod.Dataset = null;
    defer if (val_dataset) |*vd| vd.deinit();

    if (val_split > 0.0 and val_split < 1.0 and dataset.totalTokens() > context_len * 100) {
        val_dataset = try dataset.splitTrainVal(1.0 - val_split);
        try stdout.print("       Val split: {d:.0}% train ({d} tok) / {d:.0}% val ({d} tok)\n", .{
            (1.0 - val_split) * 100.0, dataset.totalTokens(),
            val_split * 100.0,         val_dataset.?.totalTokens(),
        });
    }

    // Create checkpoint directory
    std.fs.cwd().makePath(checkpoint_dir) catch |err| {
        std.log.warn("cli: failed to create checkpoint dir '{s}': {}", .{ checkpoint_dir, err });
    };

    // Initialize trainer
    try stdout.print("[3/4] Initializing trainer...\n", .{});
    const config = trainer_mod.TrainConfig{
        .lr = lr,
        .lr_min = lr_min,
        .warmup_steps = warmup_steps,
        .total_steps = total_steps,
        .batch_size = batch_size,
        .weight_decay = weight_decay_override,
        .checkpoint_every = 10000,
        .log_every = 100,
        .ste = ste_config,
        .optimizer = optimizer_type,
        .lr_schedule = lr_schedule,
        .label_smoothing = label_smoothing_val,
        .restart_period = restart_period,
        .restart_mult = restart_mult,
        .lamb_clamp = lamb_clamp_val,
        .stable_ratio = stable_ratio_val,
        .ternary_grads = t_ternary_grads,
        .adaptive_sparsity = t_adaptive_sparsity,
        .ternary_schedule = t_ternary_schedule,
        .grad_clip = grad_clip_val,
    };
    // Wire dropout into model (applied in forwardTrain before output projection)
    model.dropout_rate = dropout;
    if (dropout > 0.0) {
        // Seed dropout PRNG from seed_offset for reproducibility
        model.dropout_prng = std.Random.DefaultPrng.init(0xD20F_0000 ^ seed_offset);
        try stdout.print("       Dropout: {d:.2} (inverted, before output projection)\n", .{dropout});
    }
    const opt_name: []const u8 = if (optimizer_type == .lamb) "LAMB" else "AdamW";
    const eff_batch = batch_size * grad_accum;
    const sched_name: []const u8 = switch (lr_schedule) {
        .sacred => "sacred(phi-cosine)",
        .cosine => "cosine",
        .cosine_restarts => "cosine-restarts",
        .wsd => "WSD(warmup-stable-decay)",
        .phi_restart => "PHI-restart(phi-cosine-restarts)",
        .d2z => "D2Z(linear-to-zero)",
    };
    try stdout.print("       LR: {d:.6} → {d:.7} ({s}), Steps: {d}, Batch: {d}×{d}={d}, Ctx: {d}, Warmup: {d}, Opt: {s}\n", .{ config.lr, config.lr_min, sched_name, config.total_steps, config.batch_size, grad_accum, eff_batch, context_len, config.warmup_steps, opt_name });
    try stdout.print("       Label smoothing: {d:.2}\n", .{label_smoothing_val});
    if (lr_schedule == .cosine_restarts or lr_schedule == .phi_restart) {
        try stdout.print("       Restart period: {d}, mult: {d:.1}\n", .{ restart_period, restart_mult });
    }
    if (ste_config.mode != .none) {
        const mode_name: []const u8 = switch (ste_config.mode) {
            .vanilla => "vanilla",
            .twn => "TWN (Li et al. 2016)",
            .progressive => "progressive",
            .none => "none",
        };
        try stdout.print("       STE: {s}, threshold: {d:.2}, warmup: {d}\n", .{ mode_name, ste_config.threshold, ste_config.warmup_steps });
    }

    // Weight decay schedule: disable at 50% of training
    const wd_disable_step = total_steps / 2;
    const initial_wd = config.weight_decay;

    // Consciousness threshold warmup
    const consciousness_warmup_steps: u32 = 10000;
    const initial_threshold: f64 = 0.15;
    const final_threshold: f64 = constants.PHI_INV;

    try stdout.print("       WD: {d:.3} (cosine, disable at 50%)\n", .{initial_wd});
    try stdout.print("       Consciousness: adaptive threshold {d:.2} -> phi^-1 (warmup {d}K steps)\n", .{ initial_threshold, consciousness_warmup_steps / 1000 });
    const total_trainable = trainer_mod.totalTrainableParams(num_blocks_arg);
    try stdout.print("       Full STE backprop: {d} trainable params (100%%)\n", .{total_trainable});

    var trainer = try trainer_mod.FullTrainer.init(allocator, &model, &dataset, config);
    defer trainer.deinit();

    // Resume from checkpoint (after trainer init so optimizer buffers exist)
    if (resume_path) |rpath| {
        resume_step = trainer_mod.loadCheckpointOpt(&model, rpath, &trainer.optimizer) catch |err| {
            try stdout.print("[ERROR] Failed to load checkpoint {s}: {}\n", .{ rpath, err });
            return;
        };
        trainer.metrics.step = resume_step;
        try stdout.print("       [RESUME] Loaded checkpoint + optimizer state: {s} (step {d})\n", .{ rpath, resume_step });
    }

    // Initialize parallel trainer (N_WORKERS threads for batch processing)
    var par = try parallel_mod.ParallelTrainer.init(allocator);
    defer par.deinit();
    try stdout.print("       Parallel: {d} workers (SIMD + threading)\n", .{parallel_mod.N_WORKERS});

    // Train
    try stdout.print("[4/4] Training...\n\n", .{});
    try stdout.print("Step     | Loss     | AvgL10   | PPL      | LR       | C-Ratio  | Tok/s\n", .{});
    try stdout.print("---------|----------|----------|----------|----------|----------|--------\n", .{});

    var batch = try data_mod.Batch.init(allocator, batch_size, context_len);
    defer batch.deinit();

    // Running average loss (window=10)
    var loss_ring: [10]f32 = .{0} ** 10;
    var loss_ring_idx: usize = 0;
    var loss_ring_count: usize = 0;

    const train_start = std.time.nanoTimestamp();
    var step_tokens: u64 = 0;
    var best_ppl: f32 = std.math.inf(f32);

    while (trainer.metrics.step < total_steps) {
        // Gradient accumulation: process grad_accum micro-batches before optimizer step
        trainer.model.zeroGrad();
        var accum_loss: f32 = 0;
        par.syncWeights(trainer.model);
        for (0..grad_accum) |_| {
            dataset.nextBatch(&batch);
            const micro_loss = par.processBatch(&batch, batch_size);
            par.accumulateGradsInto(trainer.model);
            accum_loss += micro_loss;
        }
        trainer.accum_count = batch_size * grad_accum;
        step_tokens += batch_size * grad_accum * context_len;

        const batch_loss = accum_loss / @as(f32, @floatFromInt(batch_size * grad_accum));
        trainer.metrics.record(batch_loss);
        // Update running average ring buffer
        loss_ring[loss_ring_idx] = batch_loss;
        loss_ring_idx = (loss_ring_idx + 1) % 10;
        if (loss_ring_count < 10) loss_ring_count += 1;
        // Apply accumulated gradients
        trainer.optimizerStep();

        // Weight decay schedule
        if (trainer.metrics.step > wd_disable_step) {
            trainer.optimizer.setWeightDecay(0.0);
        } else {
            const wd_progress = @as(f32, @floatFromInt(trainer.metrics.step)) / @as(f32, @floatFromInt(wd_disable_step));
            const wd_cosine = (1.0 + @cos(std.math.pi * wd_progress)) / 2.0;
            trainer.optimizer.setWeightDecay(initial_wd * wd_cosine);
        }

        // Consciousness threshold warmup
        if (trainer.metrics.step < consciousness_warmup_steps) {
            const t_progress = @as(f64, @floatFromInt(trainer.metrics.step)) / @as(f64, @floatFromInt(consciousness_warmup_steps));
            const threshold = initial_threshold + (final_threshold - initial_threshold) * t_progress;
            for (trainer.model.blocks) |*block| {
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

        // Early kill: bad seeds waste compute (EXP-008, thresholds relaxed EXP-025)
        // 4 configurable stages — defaults calibrated to median convergence, not outlier seeds
        {
            const ppl = trainer.metrics.perplexity;
            const step = trainer.metrics.step;
            const KillStage = struct { gate: u32, threshold: f32 };
            const stages = [_]KillStage{
                .{ .gate = 10_000, .threshold = kill_ppl_10k },
                .{ .gate = 30_000, .threshold = kill_ppl_30k },
                .{ .gate = 60_000, .threshold = kill_ppl_60k },
                .{ .gate = 80_000, .threshold = kill_ppl_80k },
            };
            for (stages) |s| {
                if (step >= s.gate and step < s.gate + config.checkpoint_every and ppl > s.threshold) {
                    try stdout.print("[EARLY KILL] step={d} ppl={d:.2} threshold={d:.0} seed={d} loss={d:.4} — exiting cleanly\n", .{ step, ppl, s.threshold, seed_offset, trainer.metrics.loss });
                    std.log.err("EARLY KILL step={d} ppl={d:.2} threshold={d:.0} seed={d}", .{ step, ppl, s.threshold, seed_offset });
                    var kill_buf: [256]u8 = undefined;
                    const kill_path = std.fmt.bufPrint(&kill_buf, "{s}/hslm_step_{d}_killed.bin", .{ checkpoint_dir, step }) catch "killed.bin";
                    trainer_mod.saveCheckpointOpt(&model, step, trainer.metrics.loss, kill_path, &trainer.optimizer) catch {};
                    return;
                }
            }
        }

        // Checkpoint every N steps
        if (trainer.metrics.step % config.checkpoint_every == 0) {
            var path_buf: [256]u8 = undefined;
            const ckpt_path = std.fmt.bufPrint(&path_buf, "{s}/hslm_step_{d}.bin", .{ checkpoint_dir, trainer.metrics.step }) catch "checkpoint.bin";
            trainer_mod.saveCheckpointOpt(&model, trainer.metrics.step, trainer.metrics.loss, ckpt_path, &trainer.optimizer) catch |err| {
                try stdout.print("[WARN] Checkpoint failed: {}\n", .{err});
            };
            try stdout.print("[CKPT] Saved (v2 + optimizer): {s}\n", .{ckpt_path});
        }

        // Force-save at 32K — historical PPL minimum (R5=2.96, R23v2=2.90)
        if (trainer.metrics.step == 32_000) {
            var snap_buf: [256]u8 = undefined;
            const snap_path = std.fmt.bufPrint(&snap_buf, "{s}/hslm_32k_snapshot.bin", .{checkpoint_dir}) catch "hslm_32k_snapshot.bin";
            trainer_mod.saveCheckpointOpt(&model, trainer.metrics.step, trainer.metrics.loss, snap_path, &trainer.optimizer) catch {};
            try stdout.print("[CKPT] 32K snapshot saved: {s} (PPL={d:.2})\n", .{ snap_path, trainer.metrics.perplexity });
        }

        // Best PPL keeper — always overwrite with best seen so far
        if (trainer.metrics.perplexity < best_ppl) {
            best_ppl = trainer.metrics.perplexity;
            var best_buf: [256]u8 = undefined;
            const best_path = std.fmt.bufPrint(&best_buf, "{s}/hslm_best.bin", .{checkpoint_dir}) catch "hslm_best.bin";
            trainer_mod.saveCheckpointOpt(&model, trainer.metrics.step, trainer.metrics.loss, best_path, &trainer.optimizer) catch {};
            if (trainer.metrics.step % config.log_every == 0) {
                try stdout.print("[BEST] New best PPL={d:.2} at step {d}\n", .{ best_ppl, trainer.metrics.step });
            }
        }

        // Validation eval every 5K steps (P1: detect overfitting)
        if (val_dataset) |*vd| {
            if (trainer.metrics.step % 5000 == 0) {
                vd.reset();
                var val_loss_sum: f32 = 0;
                const val_iters: usize = 20;
                var val_batch = try data_mod.Batch.init(allocator, batch_size, context_len);
                defer val_batch.deinit();
                for (0..val_iters) |_| {
                    vd.nextBatch(&val_batch);
                    for (0..batch_size) |b| {
                        const input = val_batch.getInput(b);
                        const target = val_batch.getTarget(b);
                        const sl = @min(input.len, context_len);
                        // Reset KV cache for each sequence
                        for (model.blocks) |*block| {
                            block.sacred_attn.resetCache();
                        }
                        // Forward-only (inference mode, no dropout, no grad)
                        var logits: [VOCAB_SIZE]f32 = undefined;
                        model.forward(input[0..sl], &logits);
                        var grad_buf: [VOCAB_SIZE]f32 = [_]f32{0.0} ** VOCAB_SIZE;
                        var lt = autograd.Tensor{
                            .data = &logits,
                            .grad = &grad_buf,
                            .rows = 1,
                            .cols = VOCAB_SIZE,
                            .requires_grad = false,
                            .allocator = allocator,
                        };
                        val_loss_sum += autograd.forwardCrossEntropy(&lt, target[sl - 1 ..]);
                    }
                }
                const val_avg = val_loss_sum / @as(f32, @floatFromInt(val_iters * batch_size));
                const val_ppl = @exp(val_avg);
                try stdout.print("[VAL] step={d} val_loss={d:.4} val_ppl={d:.2}\n", .{
                    trainer.metrics.step, val_avg, val_ppl,
                });
            }
        }

        // Milestone text generation (early)
        if (trainer.metrics.step == 1000 or trainer.metrics.step == 2000 or trainer.metrics.step == 3000) {
            try stdout.print("\n[MILESTONE step {d}] Generated text:\n", .{trainer.metrics.step});
            try generateSample(allocator, &model, .{});
            try stdout.print("\n", .{});
        }

        // Repetition rate check every 25K steps (anti-mirage metric)
        if (trainer.metrics.step > 0 and trainer.metrics.step % 25000 == 0) {
            const rep_rate = measureRepetitionRate(allocator, &model) catch 100.0;
            try stdout.print("[REP] step={d} repetition_rate={d:.1}%\n", .{ trainer.metrics.step, rep_rate });
            if (rep_rate > 60.0) {
                try stdout.print("[REP] WARNING: repetition_rate>{d:.0}% — possible mirage (memorization without generalization)\n", .{60.0});
            }
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

    // Save final checkpoint with step number (preserved across FRESH restarts)
    var final_path_buf: [256]u8 = undefined;
    const final_path = std.fmt.bufPrint(&final_path_buf, "{s}/hslm_step_{d}_final.bin", .{ checkpoint_dir, trainer.metrics.step }) catch "hslm_final.bin";
    trainer_mod.saveCheckpointOpt(&model, trainer.metrics.step, trainer.metrics.loss, final_path, &trainer.optimizer) catch |err| {
        try stdout.print("[WARN] Final checkpoint failed: {}\n", .{err});
    };
    try stdout.print("[CKPT] Final saved (v2 + optimizer): {s}\n", .{final_path});

    // Also save legacy hslm_final.bin for backwards compat
    const legacy_path = std.fmt.bufPrint(&final_path_buf, "{s}/hslm_final.bin", .{checkpoint_dir}) catch "hslm_final.bin";
    trainer_mod.saveCheckpointOpt(&model, trainer.metrics.step, trainer.metrics.loss, legacy_path, &trainer.optimizer) catch {};

    // Generate sample
    try stdout.print("\n[SAMPLE] Generated text:\n", .{});
    try generateSample(allocator, &model, .{});
}

fn runJepaTraining(
    allocator: std.mem.Allocator,
    data_path: ?[]const u8,
    total_steps: u32,
    lr: f32,
    lr_min: f32,
    batch_size: usize,
    checkpoint_dir: []const u8,
    max_lines: usize,
    warmup_steps: u32,
    resume_path: ?[]const u8,
    seed_offset: u64,
    context_len: usize,
    grad_clip_val: f32,
    weight_decay: f32,
    ema_decay_start: f32,
    ema_decay_end: f32,
    mask_ratio: f32,
    predictor_lr_mult: f32,
    log_every: u32,
    init_zero_flag: bool,
) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print(
        \\
        \\================================================================
        \\  T-JEPA Training — Ternary Joint-Embedding Predictive Architecture
        \\  Online encoder + Target encoder (EMA) + Predictor
        \\  Objective: predict representations, not tokens
        \\================================================================
        \\
    , .{});

    // Initialize online encoder
    try stdout.print("[1/4] Initializing online encoder...\n", .{});
    var model = if (init_zero_flag)
        try model_mod.HSLM.initZero(allocator)
    else
        try model_mod.HSLM.initWithSeed(allocator, seed_offset);
    defer model.deinit();

    const mem_kb = bench_mod.memoryUsage();
    try stdout.print("       Encoder params: {d}, Memory: {d}KB\n", .{ model.paramCount(), mem_kb });

    // Load data
    try stdout.print("[2/4] Loading training data...\n", .{});
    var dataset = try data_mod.Dataset.init(allocator, context_len);
    defer dataset.deinit();

    if (data_path) |path| {
        try stdout.print("       File: {s}\n", .{path});
        const lines = try dataset.loadTextFile(path, max_lines);
        try stdout.print("       Loaded {d} stories, {d} tokens\n", .{ lines, dataset.totalTokens() });
    } else {
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

    if (dataset.totalTokens() < context_len + 1) {
        try stdout.print("[ERROR] Not enough data ({d} tokens, need > {d})\n", .{ dataset.totalTokens(), context_len + 1 });
        return;
    }

    // Create checkpoint directory
    std.fs.cwd().makePath(checkpoint_dir) catch |err| {
        std.log.warn("cli: failed to create checkpoint dir '{s}': {}", .{ checkpoint_dir, err });
    };

    // Initialize T-JEPA
    try stdout.print("[3/4] Initializing T-JEPA (online + target + predictor)...\n", .{});
    var tjepa = try tjepa_mod.TJepa.init(allocator, &model);
    defer tjepa.deinit();

    // Override mask config from CLI
    tjepa.mask_config.mask_ratio = mask_ratio;
    tjepa.ema.decay_start = ema_decay_start;
    tjepa.ema.decay_end = ema_decay_end;

    const jepa_config = tjepa_trainer_mod.TJepaConfig{
        .lr = lr,
        .lr_min = lr_min,
        .warmup_steps = warmup_steps,
        .total_steps = total_steps,
        .batch_size = batch_size,
        .grad_clip = grad_clip_val,
        .weight_decay = weight_decay,
        .ema_decay_start = ema_decay_start,
        .ema_decay_end = ema_decay_end,
        .mask_ratio = mask_ratio,
        .predictor_lr_mult = predictor_lr_mult,
        .checkpoint_every = 10000,
        .log_every = log_every,
    };

    var trainer = try tjepa_trainer_mod.TJepaTrainer.init(allocator, &tjepa, &dataset, jepa_config);
    defer trainer.deinit();

    const total_jepa_params = tjepa_mod.TJepa.totalParams();
    try stdout.print("       Total params: {d} (encoder + predictor)\n", .{total_jepa_params});
    try stdout.print("       LR: {d:.6}, Warmup: {d}, Steps: {d}, Batch: {d}, Ctx: {d}\n", .{ lr, warmup_steps, total_steps, batch_size, context_len });
    try stdout.print("       EMA decay: {d:.4} -> {d:.4}, Mask ratio: {d:.2}, Predictor LR mult: {d:.1}x\n", .{ ema_decay_start, ema_decay_end, mask_ratio, predictor_lr_mult });

    // Resume from checkpoint
    if (resume_path) |rpath| {
        const resume_step = trainer_mod.loadCheckpoint(&model, rpath) catch |err| {
            try stdout.print("[ERROR] Failed to load checkpoint {s}: {}\n", .{ rpath, err });
            return;
        };
        trainer.metrics.step = resume_step;
        try stdout.print("       [RESUME] Loaded checkpoint: {s} (step {d})\n", .{ rpath, resume_step });
    }

    // Train
    try stdout.print("[4/4] Training T-JEPA...\n\n", .{});
    try stdout.print("Step     | MSE      | AvgMSE10 | ReprVar  | EMA-tau  | LR       | Tok/s\n", .{});
    try stdout.print("---------|----------|----------|----------|----------|----------|------\n", .{});

    var batch = try data_mod.Batch.init(allocator, batch_size, context_len);
    defer batch.deinit();

    // Running average loss (window=10)
    var loss_ring: [10]f32 = .{0} ** 10;
    var loss_ring_idx: usize = 0;
    var loss_ring_count: usize = 0;

    const train_start = std.time.nanoTimestamp();
    var step_tokens: u64 = 0;
    var best_mse: f32 = std.math.inf(f32);

    while (trainer.metrics.step < total_steps) {
        // Get batch and train
        dataset.nextBatch(&batch);
        const input = batch.getInput(0);
        const sl = @min(input.len, context_len);
        const loss = trainer.trainStep(input[0..sl]);
        step_tokens += batch_size * context_len;

        // Update running average
        loss_ring[loss_ring_idx] = loss;
        loss_ring_idx = (loss_ring_idx + 1) % 10;
        if (loss_ring_count < 10) loss_ring_count += 1;

        // Log
        if (trainer.metrics.step % log_every == 0) {
            const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - train_start);
            const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
            const tps = @as(f64, @floatFromInt(step_tokens)) / elapsed_s;

            var avg_sum: f32 = 0.0;
            for (0..loss_ring_count) |ri| {
                avg_sum += loss_ring[ri];
            }
            const avg_mse_10 = avg_sum / @as(f32, @floatFromInt(loss_ring_count));

            try stdout.print("{d:>8} | {d:>8.6} | {d:>8.6} | {d:>8.4} | {d:>8.6} | {d:>8.6} | {d:>6.0}\n", .{
                trainer.metrics.step,
                trainer.metrics.mse_loss,
                avg_mse_10,
                trainer.metrics.repr_variance,
                trainer.metrics.ema_decay,
                trainer.metrics.lr_current,
                tps,
            });
        }

        // Collapse warning
        if (trainer.isCollapsing() and trainer.metrics.step % 1000 == 0) {
            try stdout.print("[WARNING] Representation collapse detected! repr_variance={d:.6} < 0.01\n", .{trainer.metrics.repr_variance});
        }

        // Checkpoint
        if (trainer.metrics.step % jepa_config.checkpoint_every == 0) {
            var path_buf: [256]u8 = undefined;
            const ckpt_path = std.fmt.bufPrint(&path_buf, "{s}/jepa_step_{d}.bin", .{ checkpoint_dir, trainer.metrics.step }) catch "jepa_checkpoint.bin";
            trainer_mod.saveCheckpoint(&model, trainer.metrics.step, trainer.metrics.mse_loss, ckpt_path) catch |err| {
                try stdout.print("[WARN] Checkpoint failed: {}\n", .{err});
            };
            try stdout.print("[CKPT] Saved: {s}\n", .{ckpt_path});
        }

        // Best MSE keeper
        if (trainer.metrics.mse_loss < best_mse and trainer.metrics.mse_loss > 0) {
            best_mse = trainer.metrics.mse_loss;
            var best_buf: [256]u8 = undefined;
            const best_path = std.fmt.bufPrint(&best_buf, "{s}/jepa_best.bin", .{checkpoint_dir}) catch "jepa_best.bin";
            trainer_mod.saveCheckpoint(&model, trainer.metrics.step, trainer.metrics.mse_loss, best_path) catch {};
        }
    }

    // Final summary
    const total_ns: u64 = @intCast(std.time.nanoTimestamp() - train_start);
    const total_s = @as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0;

    const tps_final = @as(f64, @floatFromInt(step_tokens)) / total_s;

    try stdout.print(
        \\
        \\================================================================
        \\  T-JEPA Training Complete!
        \\================================================================
        \\  Steps:        {d}
        \\  Final MSE:    {d:.6}
        \\  Best MSE:     {d:.6} (step {d})
        \\  Avg MSE:      {d:.6}
        \\  ReprVar@Best: {d:.4}
        \\  ReprVar@End:  {d:.4}
        \\  EMA decay:    {d:.6}
        \\  Time:         {d:.1}s
        \\  Throughput:   {d:.0} tok/s
        \\================================================================
        \\
    , .{
        trainer.metrics.step,
        trainer.metrics.mse_loss,
        trainer.metrics.best_loss,
        trainer.metrics.best_step,
        trainer.metrics.avgLoss(),
        trainer.metrics.reprvar_at_best,
        trainer.metrics.repr_variance,
        trainer.metrics.ema_decay,
        total_s,
        tps_final,
    });

    // Machine-parseable summary line (for observatory/leaderboard)
    try stdout.print("JEPA-SUMMARY mse_best={d:.6} reprvar={d:.4} step_best={d} steps={d} lr={d:.6} batch={d} ctx={d} ema={d:.4}->{d:.4} mask={d:.2} toks={d:.0}\n", .{
        trainer.metrics.best_loss,
        trainer.metrics.reprvar_at_best,
        trainer.metrics.best_step,
        trainer.metrics.step,
        lr,
        batch_size,
        context_len,
        ema_decay_start,
        ema_decay_end,
        mask_ratio,
        tps_final,
    });

    // Save final checkpoint
    var final_path_buf: [256]u8 = undefined;
    const final_path = std.fmt.bufPrint(&final_path_buf, "{s}/jepa_step_{d}_final.bin", .{ checkpoint_dir, trainer.metrics.step }) catch "jepa_final.bin";
    trainer_mod.saveCheckpoint(&model, trainer.metrics.step, trainer.metrics.mse_loss, final_path) catch |err| {
        try stdout.print("[WARN] Final checkpoint failed: {}\n", .{err});
    };
    try stdout.print("[CKPT] Final saved: {s}\n", .{final_path});
}

fn runHybridTraining(
    allocator: std.mem.Allocator,
    data_path: ?[]const u8,
    total_steps: u32,
    lr: f32,
    lr_min: f32,
    batch_size: usize,
    checkpoint_dir: []const u8,
    max_lines: usize,
    warmup_steps: u32,
    resume_path: ?[]const u8,
    weight_decay: f32,
    dropout: f32,
    seed_offset: u64,
    ste_config: ste_mod.SteConfig,
    optimizer_type: trainer_mod.OptimizerType,
    grad_accum: usize,
    context_len: usize,
    lr_schedule: trainer_mod.LrScheduleType,
    label_smoothing_val: f32,
    restart_period: u32,
    restart_mult: f32,
    t_ternary_grads: bool,
    t_adaptive_sparsity: bool,
    t_ternary_schedule: bool,
    lamb_clamp_val: f32,
    stable_ratio_val: f32,
    init_zero_flag: bool,
    data_shard: u32,
    num_shards: u32,
    total_lines: usize,
    val_split: f32,
    grad_clip_val: f32,
    kill_ppl_10k: f32,
    kill_ppl_30k: f32,
    kill_ppl_60k: f32,
    kill_ppl_80k: f32,
    ema_decay_start: f32,
    ema_decay_end: f32,
    mask_ratio: f32,
    predictor_lr_mult: f32,
    log_every: u32,
    num_blocks_arg: usize,
) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    const jepa_steps = total_steps / 2;
    const ntp_steps = total_steps - jepa_steps;

    try stdout.print(
        \\
        \\================================================================
        \\  HYBRID Training: Stage 1 T-JEPA ({d} steps) + Stage 2 NTP ({d} steps)
        \\================================================================
        \\
    , .{ jepa_steps, ntp_steps });

    // Stage 1: T-JEPA
    try stdout.print("\n[STAGE 1/2] T-JEPA representation learning...\n", .{});
    try runJepaTraining(allocator, data_path, jepa_steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, resume_path, seed_offset, context_len, grad_clip_val, weight_decay, ema_decay_start, ema_decay_end, mask_ratio, predictor_lr_mult, log_every, init_zero_flag);

    // Stage 2: NTP fine-tune from JEPA checkpoint
    try stdout.print("\n[STAGE 2/2] NTP fine-tuning from JEPA checkpoint...\n", .{});
    var resume_buf: [256]u8 = undefined;
    const jepa_ckpt = std.fmt.bufPrint(&resume_buf, "{s}/jepa_step_{d}_final.bin", .{ checkpoint_dir, jepa_steps }) catch "jepa_final.bin";
    try runTrain(allocator, data_path, ntp_steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, jepa_ckpt, weight_decay, dropout, seed_offset, ste_config, optimizer_type, grad_accum, context_len, lr_schedule, label_smoothing_val, restart_period, restart_mult, t_ternary_grads, t_adaptive_sparsity, t_ternary_schedule, lamb_clamp_val, stable_ratio_val, init_zero_flag, data_shard, num_shards, total_lines, val_split, grad_clip_val, kill_ppl_10k, kill_ppl_30k, kill_ppl_60k, kill_ppl_80k, num_blocks_arg);
}

// ═══════════════════════════════════════════════════════════════════════════════
// NCA PRE-PRE-TRAINING — MIT arXiv 2603.10055
// ═══════════════════════════════════════════════════════════════════════════════

fn runNcaNtpTraining(
    allocator: std.mem.Allocator,
    data_path: ?[]const u8,
    total_steps: u32,
    lr: f32,
    lr_min: f32,
    batch_size: usize,
    checkpoint_dir: []const u8,
    max_lines: usize,
    warmup_steps: u32,
    resume_path: ?[]const u8,
    weight_decay: f32,
    dropout: f32,
    seed_offset: u64,
    ste_config: ste_mod.SteConfig,
    optimizer_type: trainer_mod.OptimizerType,
    grad_accum: usize,
    context_len: usize,
    lr_schedule: trainer_mod.LrScheduleType,
    label_smoothing_val: f32,
    restart_period: u32,
    restart_mult: f32,
    t_ternary_grads: bool,
    t_adaptive_sparsity: bool,
    t_ternary_schedule: bool,
    lamb_clamp_val: f32,
    stable_ratio_val: f32,
    init_zero_flag: bool,
    data_shard: u32,
    num_shards: u32,
    total_lines: usize,
    val_split: f32,
    grad_clip_val: f32,
    kill_ppl_10k: f32,
    kill_ppl_30k: f32,
    kill_ppl_60k: f32,
    kill_ppl_80k: f32,
    num_blocks_arg: usize,
    p_nca_steps: u32,
    nca_grid: u8,
    nca_states: u8,
    nca_rollout: u16,
    p_nca_entropy_min: f32,
    p_nca_entropy_max: f32,
) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    const ntp_steps = if (total_steps > p_nca_steps) total_steps - p_nca_steps else total_steps;

    try stdout.print(
        \\
        \\================================================================
        \\  NCA→NTP Training: Stage 0 NCA ({d} steps) + Stage 1 NTP ({d} steps)
        \\  Grid: {d}x{d}, States: {d}, Rollout: {d}
        \\  Entropy band: [{d:.1}, {d:.1}]
        \\================================================================
        \\
    , .{ p_nca_steps, ntp_steps, nca_grid, nca_grid, nca_states, nca_rollout, p_nca_entropy_min, p_nca_entropy_max });

    // Stage 0: Generate NCA dataset + train with NTP loss on synthetic data
    try stdout.print("\nPHASE=nca\n[STAGE 0] NCA pre-pre-training ({d} steps)...\n", .{p_nca_steps});

    const nca_config = nca_mod.NcaConfig{
        .grid_size = nca_grid,
        .num_states = nca_states,
        .rollout_steps = nca_rollout,
        .min_entropy = p_nca_entropy_min,
        .max_entropy = p_nca_entropy_max,
        .seed = 42 + seed_offset,
    };

    // Generate synthetic tokens: nca_steps * batch_size * context_len
    const target_tokens = @as(usize, p_nca_steps) * batch_size * context_len;
    try stdout.print("  Generating {d} NCA tokens...\n", .{target_tokens});

    var nca_dataset = try nca_mod.generateNcaDataset(allocator, nca_config, target_tokens);
    defer nca_dataset.deinit(allocator);
    try stdout.print("  Generated {d} NCA tokens (entropy-filtered)\n", .{nca_dataset.items.len});

    // Create Dataset and add NCA tokens
    var ds = try data_mod.Dataset.init(allocator, context_len);
    defer ds.deinit();
    try ds.addTokens(nca_dataset.items);

    // Create model + trainer for NCA stage
    var hslm = try model_mod.HSLM.init(allocator);
    defer hslm.deinit();

    if (resume_path) |rp| {
        try stdout.print("  Resuming from checkpoint: {s}\n", .{rp});
        _ = trainer_mod.loadCheckpoint(&hslm, rp) catch |err| {
            try stdout.print("  WARNING: Failed to load checkpoint: {}\n", .{err});
        };
    }

    var ft = try trainer_mod.FullTrainer.init(allocator, &hslm, &ds, trainer_mod.TrainConfig{
        .total_steps = p_nca_steps,
        .lr = lr,
        .lr_min = lr_min,
        .batch_size = batch_size,
        .warmup_steps = warmup_steps,
        .weight_decay = weight_decay,
        .optimizer = optimizer_type,
        .lr_schedule = lr_schedule,
        .label_smoothing = label_smoothing_val,
        .restart_period = restart_period,
        .restart_mult = restart_mult,
        .lamb_clamp = lamb_clamp_val,
        .stable_ratio = stable_ratio_val,
        .grad_clip = grad_clip_val,
        .ste = ste_config,
    });
    defer ft.deinit();

    // Train NCA stage
    var batch_data = try data_mod.Batch.init(allocator, batch_size, context_len);
    defer batch_data.deinit();

    var step: u32 = 0;
    while (step < p_nca_steps) : (step += 1) {
        ds.nextBatch(&batch_data);
        var total_loss: f32 = 0;
        for (0..batch_size) |b| {
            total_loss += ft.trainStep(batch_data.getInput(b), batch_data.getTarget(b));
        }
        const avg_loss = total_loss / @as(f32, @floatFromInt(batch_size));

        if (step % 100 == 0) {
            const ppl = @exp(avg_loss);
            try stdout.print("  [NCA] step={d}/{d} loss={d:.4} ppl={d:.2}\n", .{ step, p_nca_steps, avg_loss, ppl });
        }
    }

    // Save NCA checkpoint
    var nca_ckpt_buf: [256]u8 = undefined;
    const nca_ckpt_path = std.fmt.bufPrint(&nca_ckpt_buf, "{s}/nca_step_{d}_final.bin", .{ checkpoint_dir, p_nca_steps }) catch "nca_final.bin";
    trainer_mod.saveCheckpoint(&hslm, p_nca_steps, 0, nca_ckpt_path) catch |err| {
        try stdout.print("  WARNING: Failed to save NCA checkpoint: {}\n", .{err});
    };
    try stdout.print("  NCA checkpoint saved: {s}\n", .{nca_ckpt_path});

    // Stage 1: NTP on real data from NCA checkpoint
    try stdout.print("\nPHASE=ntp\n[STAGE 1] NTP training from NCA checkpoint ({d} steps)...\n", .{ntp_steps});
    try runTrain(allocator, data_path, ntp_steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, nca_ckpt_path, weight_decay, dropout, seed_offset, ste_config, optimizer_type, grad_accum, context_len, lr_schedule, label_smoothing_val, restart_period, restart_mult, t_ternary_grads, t_adaptive_sparsity, t_ternary_schedule, lamb_clamp_val, stable_ratio_val, init_zero_flag, data_shard, num_shards, total_lines, val_split, grad_clip_val, kill_ppl_10k, kill_ppl_30k, kill_ppl_60k, kill_ppl_80k, num_blocks_arg);
}

fn runNcaJepaNtpTraining(
    allocator: std.mem.Allocator,
    data_path: ?[]const u8,
    total_steps: u32,
    lr: f32,
    lr_min: f32,
    batch_size: usize,
    checkpoint_dir: []const u8,
    max_lines: usize,
    warmup_steps: u32,
    resume_path: ?[]const u8,
    weight_decay: f32,
    dropout: f32,
    seed_offset: u64,
    ste_config: ste_mod.SteConfig,
    optimizer_type: trainer_mod.OptimizerType,
    grad_accum: usize,
    context_len: usize,
    lr_schedule: trainer_mod.LrScheduleType,
    label_smoothing_val: f32,
    restart_period: u32,
    restart_mult: f32,
    t_ternary_grads: bool,
    t_adaptive_sparsity: bool,
    t_ternary_schedule: bool,
    lamb_clamp_val: f32,
    stable_ratio_val: f32,
    init_zero_flag: bool,
    data_shard: u32,
    num_shards: u32,
    total_lines: usize,
    val_split: f32,
    grad_clip_val: f32,
    kill_ppl_10k: f32,
    kill_ppl_30k: f32,
    kill_ppl_60k: f32,
    kill_ppl_80k: f32,
    ema_decay_start: f32,
    ema_decay_end: f32,
    mask_ratio: f32,
    predictor_lr_mult: f32,
    log_every: u32,
    num_blocks_arg: usize,
    p_nca_steps: u32,
    nca_grid: u8,
    nca_states: u8,
    nca_rollout: u16,
    p_nca_entropy_min: f32,
    p_nca_entropy_max: f32,
    p_jepa_steps: u32,
) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    const remaining = if (total_steps > p_nca_steps + p_jepa_steps) total_steps - p_nca_steps - p_jepa_steps else total_steps / 2;

    try stdout.print(
        \\
        \\================================================================
        \\  NCA→JEPA→NTP Training: NCA ({d}) + JEPA ({d}) + NTP ({d})
        \\  Grid: {d}x{d}, States: {d}, Rollout: {d}
        \\  Entropy band: [{d:.1}, {d:.1}]
        \\================================================================
        \\
    , .{ p_nca_steps, p_jepa_steps, remaining, nca_grid, nca_grid, nca_states, nca_rollout, p_nca_entropy_min, p_nca_entropy_max });

    // Stage 0: NCA pre-pre-training (reuse runNcaNtpTraining logic but stop after NCA)
    try stdout.print("\nPHASE=nca\n[STAGE 0/3] NCA pre-pre-training ({d} steps)...\n", .{p_nca_steps});

    const nca_config = nca_mod.NcaConfig{
        .grid_size = nca_grid,
        .num_states = nca_states,
        .rollout_steps = nca_rollout,
        .min_entropy = p_nca_entropy_min,
        .max_entropy = p_nca_entropy_max,
        .seed = 42 + seed_offset,
    };

    const target_tokens = @as(usize, p_nca_steps) * batch_size * context_len;
    try stdout.print("  Generating {d} NCA tokens...\n", .{target_tokens});

    var nca_dataset = try nca_mod.generateNcaDataset(allocator, nca_config, target_tokens);
    defer nca_dataset.deinit(allocator);
    try stdout.print("  Generated {d} NCA tokens (entropy-filtered)\n", .{nca_dataset.items.len});

    var ds = try data_mod.Dataset.init(allocator, context_len);
    defer ds.deinit();
    try ds.addTokens(nca_dataset.items);

    var hslm = try model_mod.HSLM.init(allocator);
    defer hslm.deinit();

    if (resume_path) |rp| {
        _ = trainer_mod.loadCheckpoint(&hslm, rp) catch |err| {
            try stdout.print("  WARNING: Failed to load checkpoint: {}\n", .{err});
        };
    }

    var ft = try trainer_mod.FullTrainer.init(allocator, &hslm, &ds, trainer_mod.TrainConfig{
        .total_steps = p_nca_steps,
        .lr = lr,
        .lr_min = lr_min,
        .batch_size = batch_size,
        .warmup_steps = warmup_steps,
        .weight_decay = weight_decay,
        .optimizer = optimizer_type,
        .lr_schedule = lr_schedule,
        .label_smoothing = label_smoothing_val,
        .restart_period = restart_period,
        .restart_mult = restart_mult,
        .lamb_clamp = lamb_clamp_val,
        .stable_ratio = stable_ratio_val,
        .grad_clip = grad_clip_val,
        .ste = ste_config,
    });
    defer ft.deinit();

    var batch_data = try data_mod.Batch.init(allocator, batch_size, context_len);
    defer batch_data.deinit();

    var step: u32 = 0;
    while (step < p_nca_steps) : (step += 1) {
        ds.nextBatch(&batch_data);
        var total_loss: f32 = 0;
        for (0..batch_size) |b| {
            total_loss += ft.trainStep(batch_data.getInput(b), batch_data.getTarget(b));
        }
        const avg_loss = total_loss / @as(f32, @floatFromInt(batch_size));

        if (step % 100 == 0) {
            const ppl = @exp(avg_loss);
            try stdout.print("  [NCA] step={d}/{d} loss={d:.4} ppl={d:.2}\n", .{ step, p_nca_steps, avg_loss, ppl });
        }
    }

    var nca_ckpt_buf: [256]u8 = undefined;
    const nca_ckpt_path = std.fmt.bufPrint(&nca_ckpt_buf, "{s}/nca_step_{d}_final.bin", .{ checkpoint_dir, p_nca_steps }) catch "nca_final.bin";
    trainer_mod.saveCheckpoint(&hslm, p_nca_steps, 0, nca_ckpt_path) catch |err| {
        try stdout.print("  WARNING: Failed to save NCA checkpoint: {}\n", .{err});
    };
    try stdout.print("  NCA checkpoint saved: {s}\n", .{nca_ckpt_path});

    // Stage 1: T-JEPA from NCA checkpoint
    try stdout.print("\nPHASE=jepa\n[STAGE 1/3] T-JEPA from NCA checkpoint ({d} steps)...\n", .{p_jepa_steps});
    try runJepaTraining(allocator, data_path, p_jepa_steps, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, nca_ckpt_path, seed_offset, context_len, grad_clip_val, weight_decay, ema_decay_start, ema_decay_end, mask_ratio, predictor_lr_mult, log_every, init_zero_flag);

    // Stage 2: NTP from JEPA checkpoint
    try stdout.print("\nPHASE=ntp\n[STAGE 2/3] NTP from JEPA checkpoint ({d} steps)...\n", .{remaining});
    var jepa_ckpt_buf: [256]u8 = undefined;
    const jepa_ckpt = std.fmt.bufPrint(&jepa_ckpt_buf, "{s}/jepa_step_{d}_final.bin", .{ checkpoint_dir, p_jepa_steps }) catch "jepa_final.bin";
    try runTrain(allocator, data_path, remaining, lr, lr_min, batch_size, checkpoint_dir, max_lines, warmup_steps, jepa_ckpt, weight_decay, dropout, seed_offset, ste_config, optimizer_type, grad_accum, context_len, lr_schedule, label_smoothing_val, restart_period, restart_mult, t_ternary_grads, t_adaptive_sparsity, t_ternary_schedule, lamb_clamp_val, stable_ratio_val, init_zero_flag, data_shard, num_shards, total_lines, val_split, grad_clip_val, kill_ppl_10k, kill_ppl_30k, kill_ppl_60k, kill_ppl_80k, num_blocks_arg);
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

const GenerateOpts = struct {
    eval_data_path: ?[]const u8 = null,
    eval_lines: usize = 1000,
    temperature: f32 = 0.8,
    top_k: usize = 27,
    rep_penalty: f32 = 1.2,
    prompt: ?[]const u8 = null,
    max_gen_tokens: usize = 200,
    context_len: usize = CONTEXT_LEN_CONST,
    num_blocks: usize = constants.DEFAULT_BLOCKS,
};

fn runGenerate(allocator: std.mem.Allocator, checkpoint_path: ?[]const u8, opts: GenerateOpts) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n[INIT] Loading HSLM model (blocks={d})...\n", .{opts.num_blocks});
    var model = try model_mod.HSLM.initWithConfig(allocator, constants.Config{ .num_blocks = opts.num_blocks });
    defer model.deinit();

    var ckpt_step: u32 = 0;
    if (checkpoint_path) |ckpt| {
        ckpt_step = try trainer_mod.loadCheckpoint(&model, ckpt);
        try stdout.print("[CKPT] Loaded checkpoint: {s} (step {d})\n", .{ ckpt, ckpt_step });
    } else {
        try stdout.print("[WARN] No --checkpoint provided, using random weights\n", .{});
    }

    // PPL evaluation
    if (opts.eval_data_path) |eval_path| {
        try evalPerplexity(allocator, &model, eval_path, opts.eval_lines, opts.context_len);
    }

    // Text generation
    try stdout.print("[GEN] Generating text (temp={d:.2}, top_k={d}, rep_penalty={d:.2}, max_tokens={d}):\n\n", .{
        opts.temperature, opts.top_k, opts.rep_penalty, opts.max_gen_tokens,
    });

    try generateSample(allocator, &model, opts);
}

fn evalPerplexity(allocator: std.mem.Allocator, model: *model_mod.HSLM, data_path: []const u8, max_lines: usize, context_len: usize) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    const train_mod = @import("train.zig");

    try stdout.print("\n[EVAL] Loading data: {s} (max {d} lines)...\n", .{ data_path, max_lines });

    const t_start = std.time.nanoTimestamp();

    var dataset = try data_mod.Dataset.init(allocator, context_len);
    defer dataset.deinit();
    const lines_loaded = try dataset.loadTextFile(data_path, max_lines);
    try stdout.print("[EVAL] Loaded {d} lines, {d} tokens\n", .{ lines_loaded, dataset.tokens.items.len });

    // Use last 10% as validation
    var val_set = try dataset.splitTrainVal(0.9);
    defer val_set.deinit();
    const val_tokens = val_set.tokens.items;
    try stdout.print("[EVAL] Validation set: {d} tokens\n", .{val_tokens.len});

    if (val_tokens.len < context_len + 1) {
        try stdout.print("[EVAL] Not enough validation tokens for PPL eval\n", .{});
        return;
    }

    // Evaluate sequences
    const seq_len = context_len;
    var total_loss: f64 = 0.0;
    var num_seqs: usize = 0;
    const max_seqs: usize = 500; // Cap for speed

    var pos: usize = 0;
    while (pos + seq_len + 1 <= val_tokens.len and num_seqs < max_seqs) : (pos += seq_len) {
        const input = val_tokens[pos .. pos + seq_len];
        const targets = val_tokens[pos + 1 .. pos + seq_len + 1];

        // Convert to u16 slices for model API
        var input_u16: [constants.CONTEXT_LEN]u16 = undefined;
        var targets_u16: [constants.CONTEXT_LEN]u16 = undefined;
        for (0..seq_len) |j| {
            input_u16[j] = input[j];
            targets_u16[j] = targets[j];
        }

        var all_logits: [constants.CONTEXT_LEN * VOCAB_SIZE]f32 = undefined;
        model.forwardAll(input_u16[0..seq_len], &all_logits);

        const loss = train_mod.sequenceLoss(&all_logits, targets_u16[0..seq_len], seq_len);
        total_loss += loss;
        num_seqs += 1;
    }

    const t_end = std.time.nanoTimestamp();
    const elapsed_ms = @as(f64, @floatFromInt(t_end - t_start)) / 1_000_000.0;

    if (num_seqs > 0) {
        const avg_loss = total_loss / @as(f64, @floatFromInt(num_seqs));
        const ppl = @exp(avg_loss);
        try stdout.print(
            \\
            \\╔══════════════════════════════════════╗
            \\║  PPL Evaluation Results               ║
            \\╠══════════════════════════════════════╣
            \\║  Sequences evaluated: {d:<16}║
            \\║  Avg loss:            {d:<14.4}  ║
            \\║  Perplexity (PPL):    {d:<14.2}  ║
            \\║  Time:                {d:<11.0} ms  ║
            \\╚══════════════════════════════════════╝
            \\
        , .{ num_seqs, @as(f32, @floatCast(avg_loss)), @as(f32, @floatCast(ppl)), elapsed_ms });
    } else {
        try stdout.print("[EVAL] No sequences evaluated\n", .{});
    }
}

/// Measure repetition rate: generate 5 samples, count % of repeated trigrams.
/// Returns 0-100 (percentage). High rate (>60%) indicates memorization / mirage.
fn measureRepetitionRate(allocator: std.mem.Allocator, model: *model_mod.HSLM) !f32 {
    var tok = try tokenizer_mod.Tokenizer.init(allocator);
    defer tok.deinit();

    const params = model_mod.HSLM.SampleParams{
        .temperature = 0.8,
        .top_k = 40,
        .rep_penalty = 1.0, // no penalty — measure raw repetition
    };
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp() & 0x7FFFFFFFFFFFFFFF)));
    const rng = prng.random();

    const prompts = [_][]const u8{ "Once upon a time", "The little cat", "She was very", "One day", "There was a" };
    var total_trigrams: usize = 0;
    var repeated_trigrams: usize = 0;

    for (prompts) |p| {
        var tokens: [256]u16 = undefined;
        const n = tok.encode(p, &tokens);
        var gen_len = n;
        for (0..100) |_| {
            if (gen_len >= 255) break;
            const next = model.generateSampled(tokens[0..gen_len], params, rng);
            tokens[gen_len] = next;
            gen_len += 1;
            if (next == tokenizer_mod.EOS_TOKEN) break;
        }
        // Count trigram repetitions in generated portion
        if (gen_len > n + 3) {
            const gen_start = n;
            const gen_count = gen_len - gen_start;
            if (gen_count >= 3) {
                var i: usize = gen_start;
                while (i + 2 < gen_len) : (i += 1) {
                    const tri = [3]u16{ tokens[i], tokens[i + 1], tokens[i + 2] };
                    total_trigrams += 1;
                    // Check if this trigram appears again later
                    var j: usize = i + 1;
                    while (j + 2 < gen_len) : (j += 1) {
                        if (tokens[j] == tri[0] and tokens[j + 1] == tri[1] and tokens[j + 2] == tri[2]) {
                            repeated_trigrams += 1;
                            break;
                        }
                    }
                }
            }
        }
    }

    if (total_trigrams == 0) return 0.0;
    return @as(f32, @floatFromInt(repeated_trigrams)) / @as(f32, @floatFromInt(total_trigrams)) * 100.0;
}

fn generateSample(allocator: std.mem.Allocator, model: *model_mod.HSLM, opts: GenerateOpts) !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();
    var tok = try tokenizer_mod.Tokenizer.init(allocator);
    defer tok.deinit();

    const params = model_mod.HSLM.SampleParams{
        .temperature = opts.temperature,
        .top_k = opts.top_k,
        .rep_penalty = opts.rep_penalty,
    };
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp() & 0x7FFFFFFFFFFFFFFF)));
    const rng = prng.random();

    const max_tok = @min(opts.max_gen_tokens, 255);

    if (opts.prompt) |custom_prompt| {
        // Single custom prompt
        const t_start = std.time.nanoTimestamp();
        var tokens: [256]u16 = undefined;
        const n = tok.encode(custom_prompt, &tokens);

        var gen_len = n;
        var tokens_generated: usize = 0;
        for (0..max_tok) |_| {
            if (gen_len >= 255) break;
            const next = model.generateSampled(tokens[0..gen_len], params, rng);
            tokens[gen_len] = next;
            gen_len += 1;
            tokens_generated += 1;
            if (next == tokenizer_mod.EOS_TOKEN) break;
        }

        const t_end = std.time.nanoTimestamp();
        const elapsed_ms = @as(f64, @floatFromInt(t_end - t_start)) / 1_000_000.0;
        const tok_per_sec = if (elapsed_ms > 0) @as(f64, @floatFromInt(tokens_generated)) / (elapsed_ms / 1000.0) else 0;

        var decoded: [2048]u8 = undefined;
        const m = tok.decode(tokens[0..gen_len], &decoded);
        try stdout.print("  > {s}\n\n", .{decoded[0..m]});
        try stdout.print("  [{d} tokens, {d:.0}ms, {d:.1} tok/s]\n", .{ tokens_generated, elapsed_ms, tok_per_sec });
    } else {
        // Default seed prompts
        const prompts = [_][]const u8{
            "Once upon a time",
            "The little cat",
            "She was very",
        };

        var total_tokens: usize = 0;
        const t_start = std.time.nanoTimestamp();

        for (prompts) |p| {
            var tokens: [256]u16 = undefined;
            const n = tok.encode(p, &tokens);

            var gen_len = n;
            for (0..max_tok) |_| {
                if (gen_len >= 255) break;
                const next = model.generateSampled(tokens[0..gen_len], params, rng);
                tokens[gen_len] = next;
                gen_len += 1;
                total_tokens += 1;
                if (next == tokenizer_mod.EOS_TOKEN) break;
            }

            var decoded: [2048]u8 = undefined;
            const m_dec = tok.decode(tokens[0..gen_len], &decoded);
            try stdout.print("  > {s}\n", .{decoded[0..m_dec]});
        }

        const t_end = std.time.nanoTimestamp();
        const elapsed_ms = @as(f64, @floatFromInt(t_end - t_start)) / 1_000_000.0;
        const tok_per_sec = if (elapsed_ms > 0) @as(f64, @floatFromInt(total_tokens)) / (elapsed_ms / 1000.0) else 0;

        try stdout.print("\n  [{d} tokens total, {d:.0}ms, {d:.1} tok/s]\n", .{ total_tokens, elapsed_ms, tok_per_sec });
    }
}

test "cli compiles" {
    // Verify imports resolve
    _ = model_mod.HSLM;
    _ = trainer_mod.FullTrainer;
    _ = bench_mod.BenchResult;
}
