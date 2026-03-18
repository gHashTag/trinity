// HSLM Training Entrypoint v12 — Pure Zig replacement for entrypoint-train.sh
//
// Reads env vars, finds latest checkpoint, execs hslm-train.
// Zero bash. Zero Python. Zero dependencies.
//
// phi^2 + 1/phi^2 = 3 = TRINITY

const std = @import("std");
const posix = std.posix;
const log = std.log.scoped(.entrypoint);

// Health server for Railway ToS compliance (prevents "mining" detection)
const health_server = @import("health_server.zig");

const TrainConfig = struct {
    steps: u32 = 100000,
    lr: []const u8 = "3e-4",
    lr_min: []const u8 = "1e-6",
    batch: []const u8 = "66",
    warmup: []const u8 = "5000",
    wd: []const u8 = "0.1",
    dropout: []const u8 = "0.1",
    seed: []const u8 = "0",
    optimizer: []const u8 = "adamw",
    grad_accum: []const u8 = "1",
    context: []const u8 = "81",
    blocks: []const u8 = "3",
    lr_schedule: []const u8 = "sacred",
    label_smoothing: []const u8 = "0.1",
    restart_period: []const u8 = "25000",
    restart_mult: []const u8 = "1.0",
    lamb_clamp: []const u8 = "10.0",
    stable_ratio: []const u8 = "0.7",
    data_path: []const u8 = "/data/tinystories/train_100k.txt",
    checkpoint_dir: []const u8 = "/data/checkpoints",
    fresh: bool = false,

    // STE
    ste_mode: []const u8 = "none",
    ste_threshold: []const u8 = "0.5",
    ste_warmup: []const u8 = "10000",

    // Init mode
    init_zero: bool = false,

    // Ternary flags
    full_ternary: bool = false,
    ternary_grads: bool = false,
    adaptive_sparsity: bool = false,
    ternary_schedule: bool = false,

    // T-JEPA objective
    objective: []const u8 = "ntp", // ntp | jepa | hybrid
    ema_decay_start: []const u8 = "0.996",
    ema_decay_end: []const u8 = "1.0",
    mask_ratio: []const u8 = "0.3",
    predictor_lr_mult: []const u8 = "2.0",

    // NCA pre-pre-training
    nca_steps: []const u8 = "15000",
    nca_grid: []const u8 = "9",
    nca_states: []const u8 = "9",
    nca_rollout: []const u8 = "128",
    nca_entropy_min: []const u8 = "1.5",
    nca_entropy_max: []const u8 = "2.8",
    jepa_steps: []const u8 = "0",

    // Data sharding (T10)
    data_shard: []const u8 = "0",
    num_shards: []const u8 = "1",
    total_lines: []const u8 = "15600056",

    // Validation split (P1)
    val_split: []const u8 = "0.1",

    // Gradient clipping
    grad_clip: []const u8 = "1.0",

    // Early kill thresholds (EXP-026: relaxed further — ctx=243 needs ~250@10K, ~80@30K)
    kill_ppl_10k: []const u8 = "800",
    kill_ppl_30k: []const u8 = "400",
    kill_ppl_60k: []const u8 = "200",
    kill_ppl_80k: []const u8 = "80",
};

fn envStr(key: []const u8, default: []const u8) []const u8 {
    return posix.getenv(key) orelse default;
}

fn envBool(key: []const u8, default: bool) bool {
    const val = posix.getenv(key) orelse return default;
    return std.mem.eql(u8, val, "1") or std.mem.eql(u8, val, "true");
}

fn readConfig() TrainConfig {
    return .{
        .steps = std.fmt.parseInt(u32, envStr("HSLM_STEPS", "100000"), 10) catch 100000,
        .lr = envStr("HSLM_LR", "3e-4"),
        .lr_min = envStr("HSLM_LR_MIN", "1e-6"),
        .batch = envStr("HSLM_BATCH", "66"),
        .warmup = envStr("HSLM_WARMUP", "5000"),
        .wd = envStr("HSLM_WD", "0.1"),
        .dropout = envStr("HSLM_DROPOUT", "0.1"),
        .seed = envStr("HSLM_SEED", "0"),
        .optimizer = envStr("HSLM_OPTIMIZER", "adamw"),
        .grad_accum = envStr("HSLM_GRAD_ACCUM", "1"),
        .context = envStr("HSLM_CONTEXT", "81"),
        .blocks = envStr("HSLM_BLOCKS", "3"),
        .lr_schedule = envStr("HSLM_LR_SCHEDULE", "sacred"),
        .label_smoothing = envStr("HSLM_LABEL_SMOOTHING", "0.1"),
        .restart_period = envStr("HSLM_RESTART_PERIOD", "25000"),
        .restart_mult = envStr("HSLM_RESTART_MULT", "1.0"),
        .lamb_clamp = envStr("HSLM_LAMB_CLAMP", "10.0"),
        .stable_ratio = envStr("HSLM_STABLE_RATIO", "0.7"),
        .data_path = envStr("HSLM_DATA", "/data/tinystories/train_100k.txt"),
        .checkpoint_dir = envStr("HSLM_CKPT_DIR", "/data/checkpoints"),
        .fresh = envBool("HSLM_FRESH", false),
        .ste_mode = envStr("HSLM_STE", "none"),
        .ste_threshold = envStr("HSLM_STE_THRESHOLD", "0.5"),
        .ste_warmup = envStr("HSLM_STE_WARMUP", "10000"),
        .init_zero = envBool("HSLM_INIT_ZERO", false),
        .full_ternary = envBool("HSLM_FULL_TERNARY", false),
        .ternary_grads = envBool("HSLM_TERNARY_GRADS", false),
        .adaptive_sparsity = envBool("HSLM_ADAPTIVE_SPARSITY", false),
        .ternary_schedule = envBool("HSLM_TERNARY_SCHEDULE", false),

        // NCA pre-pre-training
        .nca_steps = envStr("HSLM_NCA_STEPS", "15000"),
        .nca_grid = envStr("HSLM_NCA_GRID", "9"),
        .nca_states = envStr("HSLM_NCA_STATES", "9"),
        .nca_rollout = envStr("HSLM_NCA_ROLLOUT", "128"),
        .nca_entropy_min = envStr("HSLM_NCA_ENTROPY_MIN", "1.5"),
        .nca_entropy_max = envStr("HSLM_NCA_ENTROPY_MAX", "2.8"),
        .jepa_steps = envStr("HSLM_JEPA_STEPS", "0"),

        // T-JEPA objective
        .objective = envStr("HSLM_OBJECTIVE", "ntp"),
        .ema_decay_start = envStr("HSLM_EMA_DECAY_START", "0.996"),
        .ema_decay_end = envStr("HSLM_EMA_DECAY_END", "1.0"),
        .mask_ratio = envStr("HSLM_MASK_RATIO", "0.3"),
        .predictor_lr_mult = envStr("HSLM_PREDICTOR_LR_MULT", "2.0"),

        // Data sharding
        .data_shard = envStr("HSLM_DATA_SHARD", "0"),
        .num_shards = envStr("HSLM_NUM_SHARDS", "1"),
        .total_lines = envStr("HSLM_TOTAL_LINES", "15600056"),

        // Validation split
        .val_split = envStr("HSLM_VAL_SPLIT", "0.1"),
        .grad_clip = envStr("HSLM_GRAD_CLIP", "1.0"),

        // Early kill thresholds
        .kill_ppl_10k = envStr("HSLM_KILL_PPL_10K", "800"),
        .kill_ppl_30k = envStr("HSLM_KILL_PPL_30K", "400"),
        .kill_ppl_60k = envStr("HSLM_KILL_PPL_60K", "200"),
        .kill_ppl_80k = envStr("HSLM_KILL_PPL_80K", "80"),
    };
}

/// Find the latest hslm_step_*.bin checkpoint by iterating the directory
fn findLatestCheckpoint(allocator: std.mem.Allocator, dir_path: []const u8) ?[]const u8 {
    var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch return null;
    defer dir.close();

    var best_step: u64 = 0;
    var best_name: ?[]const u8 = null;

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        const name = entry.name;

        // Match pattern: hslm_step_NNNN.bin
        if (std.mem.startsWith(u8, name, "hslm_step_") and std.mem.endsWith(u8, name, ".bin")) {
            const num_str = name["hslm_step_".len .. name.len - ".bin".len];
            const step_num = std.fmt.parseInt(u64, num_str, 10) catch continue;
            if (step_num > best_step) {
                best_step = step_num;
                // Free previous allocation
                if (best_name) |prev| allocator.free(prev);
                best_name = allocator.dupe(u8, name) catch continue;
            }
        }
    }

    if (best_name) |name| {
        // Build full path
        const full = std.fmt.allocPrint(allocator, "{s}/{s}", .{ dir_path, name }) catch {
            allocator.free(name);
            return null;
        };
        allocator.free(name);
        return full;
    }
    return null;
}

/// Ensure directory exists, creating it if needed
fn ensureDir(path: []const u8) !void {
    std.fs.makeDirAbsolute(path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

/// Check if a file exists
fn fileExists(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}

/// Clear old checkpoints for fresh start (preserves *_final.bin)
fn clearCheckpoints(dir_path: []const u8) void {
    var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch return;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .file) continue;
        // Preserve final checkpoints (hslm_step_NNNN_final.bin)
        if (std.mem.endsWith(u8, entry.name, "_final.bin")) continue;
        if (std.mem.startsWith(u8, entry.name, "hslm_step_") or
            std.mem.eql(u8, entry.name, "hslm_final.bin"))
        {
            dir.deleteFile(entry.name) catch {};
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = readConfig();

    // Banner
    log.info("=== HSLM Entrypoint v12 (Zig) ===", .{});
    log.info("Branchless matmul: enabled (compiled-in, 38/38 ops)", .{});
    log.info("Config: steps={d} lr={s} batch={s} warmup={s} wd={s} optimizer={s}", .{
        config.steps, config.lr, config.batch, config.warmup, config.wd, config.optimizer,
    });
    log.info("  grad_accum={s} context={s} lr_schedule={s} label_smoothing={s} grad_clip={s}", .{
        config.grad_accum, config.context, config.lr_schedule, config.label_smoothing, config.grad_clip,
    });
    log.info("Data: {s}", .{config.data_path});
    log.info("Checkpoint dir: {s}", .{config.checkpoint_dir});

    // Ensure directories
    // Split data_path to get parent dir
    if (std.mem.lastIndexOf(u8, config.data_path, "/")) |idx| {
        ensureDir(config.data_path[0..idx]) catch |err| {
            log.err("Cannot create data dir: {}", .{err});
        };
    }
    ensureDir(config.checkpoint_dir) catch |err| {
        log.err("Cannot create checkpoint dir: {}", .{err});
    };

    // Check dataset exists
    if (!fileExists(config.data_path)) {
        log.err("Dataset not found: {s}", .{config.data_path});
        log.err("Download TinyStories first or set HSLM_DATA to an existing file", .{});
        return error.DatasetNotFound;
    }
    log.info("Dataset found: {s}", .{config.data_path});

    // Auto-resume logic
    var resume_path: ?[]const u8 = null;
    if (config.fresh) {
        // Check if valuable checkpoints exist before clearing
        const existing = findLatestCheckpoint(allocator, config.checkpoint_dir);
        if (existing) |ckpt| {
            log.warn("FRESH=1 but checkpoint exists: {s}", .{ckpt});
            log.warn("Clearing checkpoints (set HSLM_FRESH=0 to resume instead)", .{});
            allocator.free(ckpt);
        }
        log.info("FRESH=1: clearing old checkpoints", .{});
        clearCheckpoints(config.checkpoint_dir);
        log.info("Starting fresh (no resume)", .{});
    } else {
        resume_path = findLatestCheckpoint(allocator, config.checkpoint_dir);
        if (resume_path) |p| {
            log.info("Resuming from: {s}", .{p});
        } else {
            log.info("No checkpoint found, starting fresh", .{});
        }
    }

    // Build argv for exec (fixed buffer — max ~40 args)
    var buf: [64][]const u8 = undefined;
    var argc: usize = 0;

    const steps_str = try std.fmt.allocPrint(allocator, "{d}", .{config.steps});

    buf[argc] = "/usr/local/bin/hslm-train";
    argc += 1;
    inline for (.{
        .{ "--data", config.data_path },
        .{ "--steps", steps_str },
        .{ "--lr", config.lr },
        .{ "--lr-min", config.lr_min },
        .{ "--batch", config.batch },
        .{ "--warmup", config.warmup },
        .{ "--optimizer", config.optimizer },
        .{ "--checkpoint-dir", config.checkpoint_dir },
        .{ "--seed", config.seed },
    }) |pair| {
        buf[argc] = pair[0];
        argc += 1;
        buf[argc] = pair[1];
        argc += 1;
    }

    // Optional flags (only if non-default)
    const Pair = struct { flag: []const u8, val: []const u8, default: []const u8 };
    const optionals = [_]Pair{
        .{ .flag = "--wd", .val = config.wd, .default = "0.1" },
        .{ .flag = "--dropout", .val = config.dropout, .default = "0.0" },
        .{ .flag = "--grad-accum", .val = config.grad_accum, .default = "1" },
        .{ .flag = "--context", .val = config.context, .default = "81" },
        .{ .flag = "--blocks", .val = config.blocks, .default = "3" },
        .{ .flag = "--lr-schedule", .val = config.lr_schedule, .default = "sacred" },
        .{ .flag = "--label-smoothing", .val = config.label_smoothing, .default = "0.1" },
        .{ .flag = "--data-shard", .val = config.data_shard, .default = "0" },
        .{ .flag = "--num-shards", .val = config.num_shards, .default = "1" },
        .{ .flag = "--total-lines", .val = config.total_lines, .default = "15600056" },
        .{ .flag = "--val-split", .val = config.val_split, .default = "0.0" },
        .{ .flag = "--grad-clip", .val = config.grad_clip, .default = "1.0" },
        .{ .flag = "--kill-ppl-10k", .val = config.kill_ppl_10k, .default = "800" },
        .{ .flag = "--kill-ppl-30k", .val = config.kill_ppl_30k, .default = "400" },
        .{ .flag = "--kill-ppl-60k", .val = config.kill_ppl_60k, .default = "200" },
        .{ .flag = "--kill-ppl-80k", .val = config.kill_ppl_80k, .default = "80" },
    };
    for (optionals) |opt| {
        if (!std.mem.eql(u8, opt.val, opt.default)) {
            buf[argc] = opt.flag;
            argc += 1;
            buf[argc] = opt.val;
            argc += 1;
        }
    }

    // Cosine/phi restarts params
    if (std.mem.eql(u8, config.lr_schedule, "cosine-restarts") or std.mem.eql(u8, config.lr_schedule, "phi-restart")) {
        buf[argc] = "--restart-period";
        argc += 1;
        buf[argc] = config.restart_period;
        argc += 1;
        buf[argc] = "--restart-mult";
        argc += 1;
        buf[argc] = config.restart_mult;
        argc += 1;
    }

    // WSD stable ratio
    if (std.mem.eql(u8, config.lr_schedule, "wsd")) {
        buf[argc] = "--stable-ratio";
        argc += 1;
        buf[argc] = config.stable_ratio;
        argc += 1;
    }

    // LAMB clamp
    if (!std.mem.eql(u8, config.lamb_clamp, "10.0")) {
        buf[argc] = "--lamb-clamp";
        argc += 1;
        buf[argc] = config.lamb_clamp;
        argc += 1;
    }

    // STE
    if (!std.mem.eql(u8, config.ste_mode, "none")) {
        buf[argc] = "--ste";
        argc += 1;
        buf[argc] = config.ste_mode;
        argc += 1;
        if (!std.mem.eql(u8, config.ste_threshold, "0.5")) {
            buf[argc] = "--ste-threshold";
            argc += 1;
            buf[argc] = config.ste_threshold;
            argc += 1;
        }
        if (!std.mem.eql(u8, config.ste_warmup, "10000")) {
            buf[argc] = "--ste-warmup";
            argc += 1;
            buf[argc] = config.ste_warmup;
            argc += 1;
        }
        log.info("STE: mode={s} threshold={s} warmup={s}", .{ config.ste_mode, config.ste_threshold, config.ste_warmup });
    }

    // Resume
    if (resume_path) |p| {
        buf[argc] = "--resume";
        argc += 1;
        buf[argc] = p;
        argc += 1;
    }

    // Ternary flags
    if (config.full_ternary) {
        buf[argc] = "--full-ternary";
        argc += 1;
        log.info("Full ternary mode enabled", .{});
    }
    if (config.ternary_grads) {
        buf[argc] = "--ternary-grads";
        argc += 1;
    }
    if (config.adaptive_sparsity) {
        buf[argc] = "--adaptive-sparsity";
        argc += 1;
    }
    if (config.ternary_schedule) {
        buf[argc] = "--ternary-schedule";
        argc += 1;
    }
    if (config.init_zero) {
        buf[argc] = "--init-zero";
        argc += 1;
        log.info("Zero initialization mode enabled", .{});
    }

    // T-JEPA objective + params
    if (!std.mem.eql(u8, config.objective, "ntp")) {
        buf[argc] = "--objective";
        argc += 1;
        buf[argc] = config.objective;
        argc += 1;
        buf[argc] = "--ema-decay-start";
        argc += 1;
        buf[argc] = config.ema_decay_start;
        argc += 1;
        buf[argc] = "--ema-decay-end";
        argc += 1;
        buf[argc] = config.ema_decay_end;
        argc += 1;
        buf[argc] = "--mask-ratio";
        argc += 1;
        buf[argc] = config.mask_ratio;
        argc += 1;
        buf[argc] = "--predictor-lr-mult";
        argc += 1;
        buf[argc] = config.predictor_lr_mult;
        argc += 1;
        log.info("Objective: {s} (EMA {s}→{s}, mask {s}, pred LR ×{s})", .{
            config.objective,
            config.ema_decay_start,
            config.ema_decay_end,
            config.mask_ratio,
            config.predictor_lr_mult,
        });
    }

    // NCA pre-pre-training params
    if (std.mem.startsWith(u8, config.objective, "nca")) {
        buf[argc] = "--nca-steps";
        argc += 1;
        buf[argc] = config.nca_steps;
        argc += 1;
        buf[argc] = "--nca-grid";
        argc += 1;
        buf[argc] = config.nca_grid;
        argc += 1;
        buf[argc] = "--nca-states";
        argc += 1;
        buf[argc] = config.nca_states;
        argc += 1;
        buf[argc] = "--nca-rollout";
        argc += 1;
        buf[argc] = config.nca_rollout;
        argc += 1;
        buf[argc] = "--nca-entropy-min";
        argc += 1;
        buf[argc] = config.nca_entropy_min;
        argc += 1;
        buf[argc] = "--nca-entropy-max";
        argc += 1;
        buf[argc] = config.nca_entropy_max;
        argc += 1;
        if (!std.mem.eql(u8, config.jepa_steps, "0")) {
            buf[argc] = "--jepa-steps";
            argc += 1;
            buf[argc] = config.jepa_steps;
            argc += 1;
        }
        log.info("NCA: steps={s} grid={s} states={s} rollout={s} entropy=[{s},{s}]", .{
            config.nca_steps,       config.nca_grid,        config.nca_states, config.nca_rollout,
            config.nca_entropy_min, config.nca_entropy_max,
        });
    }

    const argv = buf[0..argc];

    // Log the full command
    log.info("Exec: {s}", .{try std.mem.join(allocator, " ", argv)});

    // URGENT: Fork to prevent Railway ToS "mining" detection
    // Parent process: runs HTTP health endpoint on port 8080
    // Child process: execs hslm-train (replaces itself)
    // Railway sees HTTP response = legitimate AI service, not crypto miner
    const pid = posix.fork() catch |err| {
        log.err("fork failed: {}", .{err});
        // Fallback: exec without health server (better than crash)
        const exec_err = posix.execvpeZ(
            try allocator.dupeZ(u8, argv[0]),
            try toExecArgs(allocator, argv),
            std.c.environ,
        );
        return exec_err;
    };

    if (pid == 0) {
        // Child process: exec hslm-train
        const err = posix.execvpeZ(
            try allocator.dupeZ(u8, argv[0]),
            try toExecArgs(allocator, argv),
            std.c.environ,
        );
        log.err("exec failed: {}", .{err});
        return error.ExecFailed;
    } else {
        // Parent process: run health endpoint
        log.info("Parent PID {d}: starting health endpoint on port 8080", .{pid});
        log.info("Child PID {d}: training process", .{pid});

        // Run health server (blocks forever)
        health_server.start(allocator) catch |err| {
            log.err("health server failed: {}", .{err});
            // Kill child process if health server dies
            posix.kill(pid, posix.SIG.TERM) catch {};
            return err;
        };
    }
}

/// Convert argv slice to null-terminated pointer array for execvpeZ
fn toExecArgs(allocator: std.mem.Allocator, items: []const []const u8) ![*:null]const ?[*:0]const u8 {
    var args = try allocator.alloc(?[*:0]const u8, items.len + 1);
    for (items, 0..) |item, i| {
        args[i] = try allocator.dupeZ(u8, item);
    }
    args[items.len] = null;
    return @ptrCast(args[0..items.len :null]);
}

test "readConfig defaults" {
    const config = readConfig();
    try std.testing.expectEqual(@as(u32, 100000), config.steps);
    try std.testing.expectEqualStrings("66", config.batch);
    try std.testing.expectEqualStrings("sacred", config.lr_schedule);
    try std.testing.expectEqual(false, config.fresh);
    try std.testing.expectEqual(false, config.full_ternary);
}

test "findLatestCheckpoint empty dir" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    // Non-existent dir returns null
    const result = findLatestCheckpoint(gpa.allocator(), "/tmp/nonexistent_hslm_test_dir");
    try std.testing.expect(result == null);
}
