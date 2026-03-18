// @origin(spec:tri_sevo.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// SEVO — Sacred EVolutionary Objective Search
// ═══════════════════════════════════════════════════════════════════════════════
//
// SEVO implements hyperparameter optimization via objective mutation in PBT.
// Instead of random mutations, SEVO uses sacred constants (φ-based values)
// and structured search grids for systematic exploration.
//
// Commands:
//   tri farm evolve sevo --wave <name>  — Execute predefined config wave
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const evolution_mod = @import("evolution.zig");
const EvolutionState = evolution_mod.EvolutionState;
const ServiceEntry = evolution_mod.ServiceEntry;
const MutatedConfig = evolution_mod.MutatedConfig;
const LrSchedule = evolution_mod.LrSchedule;
const farm_accounts_mod = @import("farm_accounts.zig");
const Account = farm_accounts_mod.Account;
const railway_api = @import("railway_api.zig");

const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";
const DIM = "\x1b[2m";

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

const SevoConfig = struct {
    name: []const u8,
    lr: []const u8,
    batch: u32,
    warmup: u32,
    grad_clip: f32 = 1.0,
    lr_schedule: LrSchedule = .cosine,
    context: u32 = 81,
    optimizer: []const u8 = "LAMB",
};

const SevoWave = struct {
    name: []const u8,
    description: []const u8,
    configs: []const SevoConfig,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Predefined Waves
// ═══════════════════════════════════════════════════════════════════════════════

// Wave 1: LR sweep around golden 1e-3 baseline
// Hypothesis: 5e-4 = φ^(-1)×1e-3, 1.5e-3 = φ^0.5×1e-3
const WAVE_LR_SWEEP = [_]SevoConfig{
    .{ .name = "w8-lr-500u", .lr = "5e-4", .batch = 66, .warmup = 2000 },
    .{ .name = "w8-lr-1000u", .lr = "1e-3", .batch = 66, .warmup = 2000 },
    .{ .name = "w8-lr-1500u", .lr = "1.5e-3", .batch = 66, .warmup = 2000 },
    .{ .name = "w8-lr-800u", .lr = "8e-4", .batch = 66, .warmup = 3000 },
};

// Wave 2: Batch size sweep (sacred: 32, 66, 128)
// 66 = ~φ^4, 128 = 2^7
const WAVE_BATCH_SWEEP = [_]SevoConfig{
    .{ .name = "w8-b32", .lr = "1e-3", .batch = 32, .warmup = 2000 },
    .{ .name = "w8-b66", .lr = "1e-3", .batch = 66, .warmup = 2000 },
    .{ .name = "w8-b128", .lr = "1e-3", .batch = 128, .warmup = 2000 },
};

// Wave 3: Warmup sweep
const WAVE_WARMUP_SWEEP = [_]SevoConfig{
    .{ .name = "w8-wu1k", .lr = "1e-3", .batch = 66, .warmup = 1000 },
    .{ .name = "w8-wu2k", .lr = "1e-3", .batch = 66, .warmup = 2000 },
    .{ .name = "w8-wu5k", .lr = "1e-3", .batch = 66, .warmup = 5000 },
};

// Wave 4: Combined SEVO wave (10 configs)
// Full factorial: 3 LR × 3 batch × 1 warmup ≈ 10 configs (with baseline dedup)
const WAVE_SEVO_10 = [_]SevoConfig{
    .{ .name = "w8-v1", .lr = "5e-4", .batch = 66, .warmup = 2000 },
    .{ .name = "w8-v2", .lr = "1.5e-3", .batch = 66, .warmup = 2000 },
    .{ .name = "w8-v3", .lr = "1e-3", .batch = 32, .warmup = 2000 },
    .{ .name = "w8-v4", .lr = "1e-3", .batch = 128, .warmup = 2000 },
    .{ .name = "w8-v5", .lr = "1e-3", .batch = 66, .warmup = 1000 },
    .{ .name = "w8-v6", .lr = "1e-3", .batch = 66, .warmup = 5000 },
    .{ .name = "w8-v7", .lr = "5e-4", .batch = 32, .warmup = 2000 },
    .{ .name = "w8-v8", .lr = "1.5e-3", .batch = 128, .warmup = 2000 },
    .{ .name = "w8-v9", .lr = "8e-4", .batch = 66, .warmup = 3000 },
    .{ .name = "w8-v10", .lr = "1e-3", .batch = 66, .warmup = 2000 }, // baseline
};

// Wave registry
const WAVES = [_]SevoWave{
    .{ .name = "lr-sweep", .description = "LR sweep: 5e-4, 1e-3, 1.5e-3, 8e-4", .configs = &WAVE_LR_SWEEP },
    .{ .name = "batch-sweep", .description = "Batch sweep: 32, 66, 128", .configs = &WAVE_BATCH_SWEEP },
    .{ .name = "warmup-sweep", .description = "Warmup sweep: 1K, 2K, 5K", .configs = &WAVE_WARMUP_SWEEP },
    .{ .name = "sevo-10", .description = "Full SEVO wave: 10 optimized configs", .configs = &WAVE_SEVO_10 },
};

// ═══════════════════════════════════════════════════════════════════════════════
// Public API
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runSevoCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "list")) {
        return runSevoList();
    } else if (std.mem.eql(u8, subcmd, "inject") or std.mem.eql(u8, subcmd, "wave")) {
        return runSevoInject(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printSevoHelp();
    } else {
        print("{s}Unknown SEVO subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printSevoHelp();
    }
}

fn printSevoHelp() void {
    print("\n{s}SEVO — Sacred EVolutionary Objective Search{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("Commands:\n", .{});
    print("  tri farm evolve sevo list           — List available waves\n", .{});
    print("  tri farm evolve sevo inject <wave>  — Execute wave (inject configs)\n", .{});
    print("  tri farm evolve sevo wave <wave>    — Same as inject\n", .{});
    print("\nAvailable waves:\n", .{});
    for (WAVES) |wave| {
        print("  {s}{s}{s} — {d} configs — {s}\n", .{ CYAN, wave.name, RESET, wave.configs.len, wave.description });
    }
    print("\nExample:\n", .{});
    print("  tri farm evolve sevo inject sevo-10\n", .{});
    print("\n", .{});
}

fn runSevoList() void {
    print("\n{s}🌊 SEVO WAVES{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    for (WAVES) |wave| {
        print("{s}{s}{s} — {s}\n", .{ BOLD, wave.name, RESET, wave.description });
        print("   {d} configs:\n", .{wave.configs.len});
        for (wave.configs, 0..) |cfg, i| {
            print("   [{d}] {s}  LR={s}  b={d}  WU={d}\n", .{ i + 1, cfg.name, cfg.lr, cfg.batch, cfg.warmup });
        }
        print("\n", .{});
    }
}

fn runSevoInject(allocator: Allocator, args: []const []const u8) !void {
    var wave_name: ?[]const u8 = null;
    var dry_run = false;
    var force_recycle = false;
    var objective: []const u8 = "ntp";

    // Parse args
    var arg_idx: usize = 0;
    while (arg_idx < args.len) : (arg_idx += 1) {
        if (std.mem.eql(u8, args[arg_idx], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[arg_idx], "--force")) {
            force_recycle = true;
        } else if (std.mem.eql(u8, args[arg_idx], "--objective") and arg_idx + 1 < args.len) {
            arg_idx += 1;
            objective = args[arg_idx];
        } else if (!std.mem.eql(u8, args[arg_idx], "--")) {
            wave_name = args[arg_idx];
        }
    }

    const wave = if (wave_name) |wn| find_wave: {
        for (WAVES) |w| {
            if (std.mem.eql(u8, w.name, wn)) break :find_wave &w;
        }
        print("{s}ERROR: Wave '{s}' not found. Run 'tri farm evolve sevo list'{s}\n", .{ RED, wn, RESET });
        return error.WaveNotFound;
    } else {
        print("{s}ERROR: Specify wave name. Run 'tri farm evolve sevo list'{s}\n", .{ RED, RESET });
        return error.WaveRequired;
    };

    // Load evolution state
    var state = try evolution_mod.loadState(allocator);
    defer evolution_mod.saveState(state) catch |err| {
        print("  {s}⚠️  Failed to save state: {}{s}\n", .{ YELLOW, err, RESET });
    };

    // Collect metrics to get latest service status
    print("{s}📊 Collecting metrics...{s}\n", .{ CYAN, RESET });
    var api_calls_collect: u32 = 0;
    evolution_mod.collectMetricsSevo(allocator, &state, &api_calls_collect);
    print("  API calls: {d}\n\n", .{api_calls_collect});

    // Find recyclable candidates
    var candidates: [evolution_mod.MAX_SERVICES]usize = undefined;
    var cand_count: usize = 0;

    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.account_idx == 0) continue; // Skip PRIMARY
        if (svc.current_step >= 90000) continue; // Skip near-finish

        const recyclable = svc.status == .crashed or svc.status == .stalled or
            svc.status == .diverged or svc.status == .stuck or
            svc.status == .idle or svc.status == .killed;

        if (recyclable) {
            candidates[cand_count] = si;
            cand_count += 1;
        }
    }

    if (cand_count == 0) {
        print("{s}⚠️  No recyclable candidates found{s}\n", .{ YELLOW, RESET });
        return error.NoCandidates;
    }

    // Sort by PPL (worst first for recycling)
    evolution_mod.sortByPpl(&state, candidates[0..cand_count]);

    print("\n{s}🌊 SEVO WAVE:{s} {s} — {s}\n", .{ BOLD, RESET, wave.name, wave.description });
    print("   {d} configs to inject into {d} recyclable workers\n\n", .{ wave.configs.len, @min(wave.configs.len, cand_count) });

    // Display configs
    print("{s}Configurations:{s}\n", .{ BOLD, RESET });
    for (wave.configs, 0..) |cfg, idx| {
        print("  [{d}] {s}  LR={s}  b={d}  WU={d}\n", .{ idx + 1, cfg.name, cfg.lr, cfg.batch, cfg.warmup });
    }
    print("\n", .{});

    if (dry_run) {
        print("{s}--dry-run: no action taken{s}\n\n", .{ DIM, RESET });
        return;
    }

    // Inject configs
    var injected_count: u32 = 0;
    var api_calls: u32 = 0;
    const base_seed: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())));

    const configs_to_inject = @min(wave.configs.len, cand_count);

    for (wave.configs[0..configs_to_inject]) |cfg| {
        if (injected_count >= cand_count) break;

        const target_idx = candidates[injected_count];
        const target = &state.services[target_idx];

        // Build MutatedConfig from SevoConfig
        var config = MutatedConfig{
            .lr_str = undefined,
            .lr_len = 0,
            .batch_str = undefined,
            .batch_len = 0,
            .optimizer_str = undefined,
            .optimizer_len = 0,
            .seed = base_seed + injected_count,
            .grad_clip = cfg.grad_clip,
            .warmup = cfg.warmup,
            .lr_schedule = cfg.lr_schedule,
            .context = cfg.context,
            .sacred = true,
            .objective = objective,
            .fresh = false,
        };

        // Copy LR string
        @memcpy(config.lr_str[0..cfg.lr.len], cfg.lr);
        config.lr_len = @intCast(cfg.lr.len);

        // Format batch string
        const batch_str = std.fmt.bufPrint(&config.batch_str, "{d}", .{cfg.batch}) catch "66";
        config.batch_len = @intCast(batch_str.len);

        // Copy optimizer string
        @memcpy(config.optimizer_str[0..cfg.optimizer.len], cfg.optimizer);
        config.optimizer_len = @intCast(cfg.optimizer.len);

        print("{s}💉 [{d}] {s} ← {s} (LR={s}, b={d}, WU={d}){s}\n", .{ CYAN, injected_count + 1, target.svcName(), cfg.name, cfg.lr, cfg.batch, cfg.warmup, RESET });

        // Recycle service with new config
        evolution_mod.recycleService(allocator, &state, target_idx, config, cfg.name, &api_calls);

        // Record lineage
        var detail_buf: [128]u8 = undefined;
        const detail = std.fmt.bufPrint(&detail_buf, "SEVO wave={s} config={s}", .{ wave.name, cfg.name }) catch "SEVO";
        state.addEvent(.spawn, target.svcName(), detail);

        injected_count += 1;
    }

    // Save lineage (append to JSONL)
    {
        const ts = std.time.milliTimestamp();
        for (wave.configs[0..configs_to_inject]) |cfg| {
            var line_buf: [256]u8 = undefined;
            const line = std.fmt.bufPrint(&line_buf, "{{\"ts\":{d},\"wave\":\"{s}\",\"config\":\"{s}\",\"lr\":\"{s}\",\"batch\":{d},\"warmup\":{d}}}\n", .{ ts, wave.name, cfg.name, cfg.lr, cfg.batch, cfg.warmup }) catch continue;
            const file = try std.fs.cwd().openFile(".trinity/evolution_lineage.jsonl", .{ .mode = .write_only });
            defer file.close();
            try file.seekFromEnd(0);
            try file.writeAll(line);
        }
    }

    print("\n{s}✅ SEVO WAVE COMPLETE:{s}\n", .{ GREEN, RESET });
    print("   Configs injected: {d}/{d}\n", .{ injected_count, wave.configs.len });
    print("   API calls: {d}\n", .{api_calls});
    print("   ETA to first PPL (~5K steps): ~30-40 min\n", .{});
    print("\n", .{});
}
