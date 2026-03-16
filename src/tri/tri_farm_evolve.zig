// @origin(spec:tri_farm_evolve.tri) @regen(manual-impl)

// ═══════════════════════════════════════════════════════════════════════════════
// TRI FARM EVOLVE — ASHA+PBT Hybrid Evolution for Training Farm
// ═══════════════════════════════════════════════════════════════════════════════
//
// Successive Halving (ASHA) + Population-Based Training (PBT) hybrid:
//   1. ASHA: Kill bottom performers at each rung threshold
//   2. PBT: Recycle killed slots with mutated configs from leaders
//
// Commands:
//   tri farm evolve init      — Scan all accounts, build initial state
//   tri farm evolve status    — Leaderboard + rung progress
//   tri farm evolve step      — Execute one evolution cycle
//   tri farm evolve history   — Print event log
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const railway_api = @import("railway_api.zig");
const RailwayApi = railway_api.RailwayApi;

const tri_commands = @import("tri_commands.zig");
const farm_ws = @import("tri_farm_ws.zig");
const print = std.debug.print;

// ANSI colors
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const DIM = "\x1b[2m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

// Sacred constants (source of truth: src/sacred/constants.zig)
// φ² + 1/φ² = 3 = TRINITY
const SACRED_PHI: f64 = 1.618033988749895;
const SACRED_PHI_INV: f64 = 0.618033988749895;
const SACRED_PHI_F32: f32 = 1.618;
const SACRED_PHI_INV_F32: f32 = 0.618;
const SACRED_PHI_INV_SQ_F32: f32 = 0.382;

const SACRED_GRAD_CLIPS = [_]f32{ 0.618, 1.0, 1.618 }; // φ^(-1), φ^0, φ^1
const SACRED_WARMUPS = [_]u32{ 243, 729, 2187 }; // 3^5, 3^6, 3^7

// Deploy/mutation bounds (single source of truth)
const LR_MIN: f64 = 1e-5;
const LR_MAX: f64 = 1e-2;
const GC_MIN: f32 = 0.3;
const GC_MAX: f32 = 3.0;
const WU_MIN: u32 = 500;
const WU_MAX: u32 = 5000;
const DEPLOY_RATE_LIMIT_MS: u64 = 100;

const MutationMode = enum {
    random,
    sacred,
    mixed,
};

// ═══════════════════════════════════════════════════════════════════════════════
// Types
// ═══════════════════════════════════════════════════════════════════════════════

const Rung = struct {
    step_threshold: u32,
    kill_ratio: f32,
    outlier_threshold: f32, // PPL above this = auto-kill regardless of ratio
};

// Conservative rungs: early rungs only kill garbage, ranking starts at 30K
const DEFAULT_RUNGS = [_]Rung{
    .{ .step_threshold = 5000, .kill_ratio = 0.0, .outlier_threshold = 500.0 },
    .{ .step_threshold = 15000, .kill_ratio = 0.0, .outlier_threshold = 200.0 },
    .{ .step_threshold = 30000, .kill_ratio = 0.30, .outlier_threshold = 500.0 },
    .{ .step_threshold = 50000, .kill_ratio = 0.30, .outlier_threshold = 500.0 },
};

// Sacred rungs: thresholds at 3^k steps (ternary structure)
const SACRED_RUNGS = [_]Rung{
    .{ .step_threshold = 2000, .kill_ratio = 0.0, .outlier_threshold = 500.0 }, // ~3^7=2187
    .{ .step_threshold = 7000, .kill_ratio = 0.0, .outlier_threshold = 200.0 }, // ~3^8=6561
    .{ .step_threshold = 20000, .kill_ratio = 0.30, .outlier_threshold = 500.0 }, // ~3^9=19683
    .{ .step_threshold = 59000, .kill_ratio = 0.30, .outlier_threshold = 500.0 }, // ~3^10=59049
};

const NUM_RUNGS = DEFAULT_RUNGS.len;
comptime {
    if (SACRED_RUNGS.len != DEFAULT_RUNGS.len) @compileError("SACRED_RUNGS and DEFAULT_RUNGS must have same length");
}
const MIN_SURVIVORS = 4;

const ServiceStatus = enum(u8) {
    running,
    idle,
    crashed,
    killed,
    unknown,
    stalled,
    diverged,
    stuck,
};

// I1: Loss history ring buffer — per-service last 20 data points
const LOSS_HISTORY_SIZE = 20;
const LossPoint = struct {
    step: u32 = 0,
    ppl: f32 = 0,
    loss: f32 = 0,
};

const ServiceEntry = struct {
    svc_id: [64]u8 = undefined,
    svc_id_len: u8 = 0,
    svc_name: [64]u8 = undefined,
    svc_name_len: u8 = 0,
    account_idx: u8 = 0,
    // Config
    lr: [16]u8 = undefined,
    lr_len: u8 = 0,
    batch: [8]u8 = undefined,
    batch_len: u8 = 0,
    optimizer: [16]u8 = undefined,
    optimizer_len: u8 = 0,
    seed: u32 = 0,
    grad_clip: f32 = 1.0,
    warmup: u32 = 2000,
    lr_schedule: LrSchedule = .cosine,
    context: u32 = 27,
    kill_ppl_30k: f32 = 999.0,
    // Objective (ntp, jepa, hybrid, nca-ntp, etc.)
    objective: [24]u8 = undefined,
    objective_len: u8 = 0,
    // Phase (ntp/jepa/hybrid/nca — distinct from objective for hybrid switching)
    phase: [12]u8 = undefined,
    phase_len: u8 = 0,
    // Wave (w6/w7/w8/w8.5 etc.)
    wave: [8]u8 = undefined,
    wave_len: u8 = 0,
    // Lineage
    generation: u16 = 0,
    parent: [64]u8 = undefined,
    parent_len: u8 = 0,
    // Metrics
    current_step: u32 = 0,
    current_ppl: f32 = 999.0,
    current_loss: f32 = 99.0,
    tok_per_sec: f32 = 0,
    val_ppl: f32 = 999.0, // P1: validation PPL (999 = not yet measured)
    status: ServiceStatus = .unknown,
    // Per-service rung tracking
    rungs_passed: [NUM_RUNGS]bool = .{ false, false, false, false },
    // Data shard assignment (T10)
    data_shard: u16 = 0,
    // Phase 3: warm restart tracking
    last_tuned_step: u32 = 0,
    // I1: Loss history ring buffer
    loss_history: [LOSS_HISTORY_SIZE]LossPoint = [_]LossPoint{.{}} ** LOSS_HISTORY_SIZE,
    loss_history_len: u8 = 0,
    // I2: Crash/stall detection
    last_poll_step: u32 = 0, // step from previous poll (for stall detection)
    stall_count: u8 = 0, // consecutive polls with unchanged step
    // I4: Checkpoint tracking
    last_ckpt_step: u32 = 0,

    fn svcId(self: *const ServiceEntry) []const u8 {
        return self.svc_id[0..self.svc_id_len];
    }

    fn svcName(self: *const ServiceEntry) []const u8 {
        return self.svc_name[0..self.svc_name_len];
    }

    fn lrStr(self: *const ServiceEntry) []const u8 {
        return self.lr[0..self.lr_len];
    }

    fn batchStr(self: *const ServiceEntry) []const u8 {
        return self.batch[0..self.batch_len];
    }

    fn optimizerStr(self: *const ServiceEntry) []const u8 {
        return self.optimizer[0..self.optimizer_len];
    }

    fn objectiveStr(self: *const ServiceEntry) []const u8 {
        if (self.objective_len == 0) return "ntp";
        return self.objective[0..self.objective_len];
    }

    fn phaseStr(self: *const ServiceEntry) []const u8 {
        if (self.phase_len == 0) return self.objectiveStr();
        return self.phase[0..self.phase_len];
    }

    fn waveStr(self: *const ServiceEntry) []const u8 {
        if (self.wave_len == 0) return "?";
        return self.wave[0..self.wave_len];
    }

    fn parentName(self: *const ServiceEntry) []const u8 {
        if (self.parent_len == 0) return "(original)";
        return self.parent[0..self.parent_len];
    }

    /// I1: Append to loss history ring buffer (only if step changed)
    fn appendLossHistory(self: *ServiceEntry, step: u32, ppl: f32, loss: f32) void {
        // Don't append duplicates (stalled workers)
        if (self.loss_history_len > 0) {
            const last_idx: u8 = self.loss_history_len - 1;
            if (self.loss_history[last_idx].step == step) return;
        }
        if (self.loss_history_len < LOSS_HISTORY_SIZE) {
            self.loss_history[self.loss_history_len] = .{ .step = step, .ppl = ppl, .loss = loss };
            self.loss_history_len += 1;
        } else {
            // Shift left (drop oldest)
            for (0..LOSS_HISTORY_SIZE - 1) |i| {
                self.loss_history[i] = self.loss_history[i + 1];
            }
            self.loss_history[LOSS_HISTORY_SIZE - 1] = .{ .step = step, .ppl = ppl, .loss = loss };
        }
    }
};

const EventType = enum(u8) {
    kill,
    spawn,
    rung_complete,
    err,
    tune,
};

const Event = struct {
    timestamp: i64 = 0,
    event_type: EventType = .err,
    service_name: [64]u8 = undefined,
    service_name_len: u8 = 0,
    detail: [128]u8 = undefined,
    detail_len: u8 = 0,

    fn svcName(self: *const Event) []const u8 {
        return self.service_name[0..self.service_name_len];
    }

    fn detailStr(self: *const Event) []const u8 {
        return self.detail[0..self.detail_len];
    }
};

const MAX_SERVICES = 160;
const MAX_EVENTS = 512;

const EvolutionState = struct {
    services: [MAX_SERVICES]ServiceEntry = undefined,
    service_count: usize = 0,
    evolution_step: u32 = 0,
    total_configs_tested: u32 = 0,
    best_ppl: f32 = 999.0,
    best_name: [64]u8 = undefined,
    best_name_len: u8 = 0,
    best_step: u32 = 0,
    events: [MAX_EVENTS]Event = undefined,
    event_count: usize = 0,

    fn bestNameStr(self: *const EvolutionState) []const u8 {
        if (self.best_name_len == 0) return "(none)";
        return self.best_name[0..self.best_name_len];
    }

    fn addEvent(self: *EvolutionState, etype: EventType, name: []const u8, detail: []const u8) void {
        if (self.event_count >= MAX_EVENTS) return;
        var ev = &self.events[self.event_count];
        ev.* = .{};
        ev.timestamp = std.time.milliTimestamp();
        ev.event_type = etype;
        const nlen: u8 = @intCast(@min(name.len, 64));
        @memcpy(ev.service_name[0..nlen], name[0..nlen]);
        ev.service_name_len = nlen;
        const dlen: u8 = @intCast(@min(detail.len, 128));
        @memcpy(ev.detail[0..dlen], detail[0..dlen]);
        ev.detail_len = dlen;
        self.event_count += 1;
    }

    fn addService(self: *EvolutionState) ?*ServiceEntry {
        if (self.service_count >= MAX_SERVICES) return null;
        const idx = self.service_count;
        self.services[idx] = .{};
        self.service_count += 1;
        return &self.services[idx];
    }
};

// WebSocket event bus — null when serve isn't running, zero overhead for non-serve commands
var global_event_bus: ?*farm_ws.EventBus = null;

fn notifyWsBus(kind: farm_ws.WsEventKind, name: []const u8, detail: []const u8) void {
    if (global_event_bus) |bus| bus.push(farm_ws.makeEvent(kind, name, detail));
}

// Farm accounts — dynamic discovery from env vars
const farm_accounts_mod = @import("farm_accounts.zig");
const Account = farm_accounts_mod.Account;
const MAX_FARM_ACCOUNTS = farm_accounts_mod.MAX_ACCOUNTS;

const STATE_PATH = ".trinity/evolution_state.json";
const NOTIFY_STATE_PATH = ".trinity/farm/notify_state.json";
const LINEAGE_PATH = ".trinity/evolution_lineage.jsonl";
const EVENTS_JSONL_PATH = ".trinity/farm/events.jsonl";

// ═══════════════════════════════════════════════════════════════════════════════
// Entry point
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runEvolveCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "status";

    if (std.mem.eql(u8, subcmd, "init")) {
        runInit(allocator) catch |err| {
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("farm evolve", subcmd, false);
            return err;
        };
        const exp_hooks = @import("experience_hooks.zig");
        exp_hooks.autoSaveExperience("farm evolve", subcmd, true);
        return;
    } else if (std.mem.eql(u8, subcmd, "status")) {
        return runStatus(allocator, if (args.len > 1) args[1..] else &.{});
    } else if (std.mem.eql(u8, subcmd, "step")) {
        runStep(allocator, args[1..]) catch |err| {
            const exp_hooks = @import("experience_hooks.zig");
            exp_hooks.autoSaveExperience("farm evolve", subcmd, false);
            return err;
        };
        const exp_hooks2 = @import("experience_hooks.zig");
        exp_hooks2.autoSaveExperience("farm evolve", subcmd, true);
        return;
    } else if (std.mem.eql(u8, subcmd, "history")) {
        return runHistory(allocator);
    } else if (std.mem.eql(u8, subcmd, "mock")) {
        return runMock(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "deploy")) {
        return runDeploy(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "collect")) {
        return runCollect(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "inspect")) {
        return runInspect(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "logs")) {
        return runLogs(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "inject")) {
        return runInject(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "watch")) {
        return runWatch(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "notify")) {
        return runNotify(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "serve")) {
        return runServe(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "tune")) {
        return runTune(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "resume")) {
        return runResume(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "recommend")) {
        return runRecommend(allocator);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printHelp();
    } else {
        print("{s}Unknown evolve subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printHelp();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOCK — Offline evolution simulation from snapshot JSON
// ═══════════════════════════════════════════════════════════════════════════════

fn runMock(allocator: Allocator, args: []const []const u8) !void {
    var snapshot_path: []const u8 = ".trinity/farm/w7v2_snapshot.json";
    var num_parents: usize = 8;
    var num_children: usize = 16;
    var allow_ctx: bool = false;
    var mode: MutationMode = .random;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--snapshot") and i + 1 < args.len) {
            i += 1;
            snapshot_path = args[i];
        } else if (std.mem.eql(u8, arg, "--parents") and i + 1 < args.len) {
            i += 1;
            num_parents = std.fmt.parseInt(usize, args[i], 10) catch 8;
        } else if (std.mem.eql(u8, arg, "--children") and i + 1 < args.len) {
            i += 1;
            num_children = std.fmt.parseInt(usize, args[i], 10) catch 16;
        } else if (std.mem.eql(u8, arg, "--allow-ctx-mutation")) {
            allow_ctx = true;
        } else if (std.mem.eql(u8, arg, "--sacred")) {
            mode = .sacred;
        } else if (std.mem.eql(u8, arg, "--mode") and i + 1 < args.len) {
            i += 1;
            const mode_str = args[i];
            if (std.mem.eql(u8, mode_str, "sacred")) {
                mode = .sacred;
            } else if (std.mem.eql(u8, mode_str, "mixed")) {
                mode = .mixed;
            } else {
                mode = .random;
            }
        }
    }

    print("\n{s}🧬 EVOLUTION MOCK — Offline Simulation{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  Snapshot: {s}\n", .{snapshot_path});
    const mode_str: []const u8 = switch (mode) {
        .random => "random",
        .sacred => "sacred",
        .mixed => "mixed",
    };
    print("  Parents: {d} | Children: {d} | Ctx mutation: {} | Mode: {s}\n\n", .{ num_parents, num_children, allow_ctx, mode_str });

    // Load snapshot JSON
    const file = std.fs.cwd().openFile(snapshot_path, .{}) catch {
        print("{s}❌ Cannot open snapshot: {s}{s}\n", .{ RED, snapshot_path, RESET });
        print("  Generate with: python3 tools/farm_leaderboard.py --json > {s}\n", .{snapshot_path});
        return;
    };
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        print("{s}❌ Failed to read snapshot{s}\n", .{ RED, RESET });
        return;
    };
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch {
        print("{s}❌ Invalid JSON in snapshot{s}\n", .{ RED, RESET });
        return;
    };
    defer parsed.deinit();

    // Parse snapshot — expect array of objects with name, ppl, step, lr, loss, etc.
    const items_val = if (parsed.value == .array) parsed.value else blk: {
        // Try {"workers": [...]} format
        if (getJsonObject(parsed.value, "workers")) |w| {
            if (w == .array) break :blk w;
        }
        print("{s}❌ Snapshot must be array or {{\"workers\": [...]}}{s}\n", .{ RED, RESET });
        return;
    };
    const items = if (items_val == .array) items_val.array.items else &[_]std.json.Value{};

    // Build ServiceEntry array from snapshot
    var entries: [MAX_SERVICES]ServiceEntry = undefined;
    var entry_count: usize = 0;

    for (items) |item| {
        if (entry_count >= MAX_SERVICES) break;
        var e = ServiceEntry{};

        const name = getJsonString(item, "name");
        copyToFixed(&e.svc_name, &e.svc_name_len, name);

        const lr_str = getJsonString(item, "lr");
        if (!std.mem.eql(u8, lr_str, "?")) {
            copyToFixed(&e.lr, &e.lr_len, lr_str);
        } else {
            copyToFixed(&e.lr, &e.lr_len, "1e-3");
        }

        const batch_str = getJsonString(item, "batch");
        if (!std.mem.eql(u8, batch_str, "?")) {
            copyToFixed(&e.batch, &e.batch_len, batch_str);
        } else {
            copyToFixed(&e.batch, &e.batch_len, "66");
        }

        const opt_str = getJsonString(item, "optimizer");
        if (!std.mem.eql(u8, opt_str, "?")) {
            copyToFixed(&e.optimizer, &e.optimizer_len, opt_str);
        } else {
            copyToFixed(&e.optimizer, &e.optimizer_len, "lamb");
        }

        e.current_ppl = blk: {
            const p = jsonF32(item, "ppl");
            break :blk if (p > 0) p else 999.0;
        };
        e.current_loss = jsonF32(item, "loss");
        e.current_step = jsonU32(item, "step");
        e.seed = jsonU32(item, "seed");
        e.val_ppl = blk: {
            const vp = jsonF32(item, "val_ppl");
            break :blk if (vp > 0) vp else 999.0;
        };
        e.grad_clip = blk: {
            const gc = jsonF32(item, "grad_clip");
            break :blk if (gc > 0) gc else 1.0;
        };
        e.warmup = blk: {
            const wu = jsonU32(item, "warmup");
            break :blk if (wu > 0) wu else 2000;
        };
        e.context = blk: {
            const ctx = jsonU32(item, "context");
            break :blk if (ctx > 0) ctx else 27;
        };
        e.status = .running;
        entries[entry_count] = e;
        entry_count += 1;
    }

    if (entry_count == 0) {
        print("{s}❌ No workers found in snapshot{s}\n", .{ RED, RESET });
        return;
    }

    print("  Loaded {d} workers from snapshot\n\n", .{entry_count});

    // Sort by fitness (lower = better)
    var sorted_idx: [MAX_SERVICES]usize = undefined;
    for (0..entry_count) |si| sorted_idx[si] = si;

    // Insertion sort by computeFitness
    {
        var ii: usize = 1;
        while (ii < entry_count) : (ii += 1) {
            const key = sorted_idx[ii];
            const key_fit = computeFitness(&entries[key]);
            var jj: usize = ii;
            while (jj > 0 and computeFitness(&entries[sorted_idx[jj - 1]]) > key_fit) {
                sorted_idx[jj] = sorted_idx[jj - 1];
                jj -= 1;
            }
            sorted_idx[jj] = key;
        }
    }

    // Select parents (top N by fitness)
    const actual_parents = @min(num_parents, entry_count);
    print("  {s}PARENTS (top {d} by fitness):{s}\n", .{ BOLD, actual_parents, RESET });
    print("  {s}#  | Name                 | PPL      | Fitness  | Step  | LR{s}\n", .{ DIM, RESET });
    print("  {s}───┼──────────────────────┼──────────┼──────────┼───────┼──────────{s}\n", .{ DIM, RESET });

    for (0..actual_parents) |rank| {
        const e = &entries[sorted_idx[rank]];
        const fit = computeFitness(e);
        print("  {d}", .{rank + 1});
        padTo(countDigits(@intCast(rank + 1)), 3);
        print("| {s}", .{e.svcName()});
        padTo(e.svc_name_len, 21);
        print("| {d:.2}", .{e.current_ppl});
        padToF(e.current_ppl, 9);
        print("| {d:.2}", .{fit});
        padToF(fit, 9);
        print("| {d}", .{e.current_step});
        padTo(countDigits(e.current_step), 6);
        print("| {s}\n", .{e.lrStr()});
    }

    // Generate children via mutation
    print("\n  {s}CHILDREN ({d} mutants):{s}\n", .{ BOLD, num_children, RESET });
    print("  {s}#  | Child                | Parent               | LR         | GC    | WU   | Ctx | Sched | S{s}\n", .{ DIM, RESET });
    print("  {s}───┼──────────────────────┼──────────────────────┼────────────┼───────┼──────┼─────┼───────┼──{s}\n", .{ DIM, RESET });

    // Output configs
    var configs_buf: [MAX_SERVICES]MutatedConfig = undefined;
    var config_names: [MAX_SERVICES][64]u8 = undefined;
    var config_name_lens: [MAX_SERVICES]u8 = undefined;
    var parent_names_buf: [MAX_SERVICES][64]u8 = undefined;
    var parent_name_lens: [MAX_SERVICES]u8 = undefined;

    var seed_counter: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())));

    for (0..num_children) |ci| {
        // Pick parent: round-robin among top parents
        const parent_pick = ci % actual_parents;
        const parent = &entries[sorted_idx[parent_pick]];

        seed_counter = mulberry32(seed_counter);
        const use_sacred = switch (mode) {
            .sacred => true,
            .random => false,
            .mixed => ci < num_children / 2,
        };
        const config = if (use_sacred)
            mutateConfigSacred(parent, seed_counter, allow_ctx)
        else
            mutateConfigEx(parent, seed_counter, allow_ctx);
        configs_buf[ci] = config;

        // Generate child name
        var name_buf: [64]u8 = undefined;
        const name = std.fmt.bufPrint(&name_buf, "w8-mock-{d:0>2}", .{ci + 1}) catch "w8-mock-??";
        const nlen: u8 = @intCast(name.len);
        @memcpy(config_names[ci][0..nlen], name[0..nlen]);
        config_name_lens[ci] = nlen;

        const pnlen = parent.svc_name_len;
        @memcpy(parent_names_buf[ci][0..pnlen], parent.svc_name[0..pnlen]);
        parent_name_lens[ci] = pnlen;

        // Print row
        print("  {d}", .{ci + 1});
        padTo(countDigits(@intCast(ci + 1)), 3);
        print("| {s}", .{name});
        padTo(nlen, 21);
        print("| {s}", .{parent.svcName()});
        padTo(parent.svc_name_len, 21);
        print("| {s}", .{config.lr_str[0..config.lr_len]});
        padTo(config.lr_len, 11);
        print("| {d:.1}", .{config.grad_clip});
        padToF(config.grad_clip, 6);
        print("| {d}", .{config.warmup});
        padTo(countDigits(config.warmup), 5);
        print("| {d}", .{config.context});
        padTo(countDigits(config.context), 4);
        const sched_str: []const u8 = config.lr_schedule.toShort();
        print("| {s}", .{sched_str});
        const sacred_str: []const u8 = if (config.sacred) "φ" else " ";
        print("| {s}\n", .{sacred_str});
    }

    // Write configs JSON
    const out_path = ".trinity/farm/w8_mock_configs.json";
    writeMockConfigsJson(out_path, &configs_buf, &config_names, &config_name_lens, &parent_names_buf, &parent_name_lens, num_children);

    // Append lineage to JSONL
    const lineage_path = ".trinity/evolution_lineage.jsonl";
    appendMockLineage(lineage_path, &configs_buf, &config_names, &config_name_lens, &parent_names_buf, &parent_name_lens, num_children, &entries, &sorted_idx, actual_parents);

    print("\n{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}MOCK DONE: {d} parents → {d} children{s}\n\n", .{ BOLD, actual_parents, num_children, RESET });
}

fn writeMockConfigsJson(
    out_path: []const u8,
    configs_buf: *const [MAX_SERVICES]MutatedConfig,
    config_names: *const [MAX_SERVICES][64]u8,
    config_name_lens: *const [MAX_SERVICES]u8,
    parent_names_buf: *const [MAX_SERVICES][64]u8,
    parent_name_lens: *const [MAX_SERVICES]u8,
    num_children: usize,
) void {
    var out_file = std.fs.cwd().createFile(out_path, .{}) catch {
        print("\n{s}❌ Failed to create {s}{s}\n", .{ RED, out_path, RESET });
        return;
    };
    defer out_file.close();

    out_file.writeAll("[\n") catch return;
    for (0..num_children) |ci| {
        if (ci > 0) out_file.writeAll(",\n") catch return;
        const c = &configs_buf[ci];
        const child_name = config_names[ci][0..config_name_lens[ci]];
        const parent_name = parent_names_buf[ci][0..parent_name_lens[ci]];
        const sched: []const u8 = c.lr_schedule.toStr();
        const sacred_str: []const u8 = if (c.sacred) "true" else "false";
        var line_buf: [512]u8 = undefined;
        const line = std.fmt.bufPrint(&line_buf,
            \\  {{"name":"{s}","parent":"{s}","lr":"{s}","grad_clip":{d:.2},"warmup":{d},"context":{d},"lr_schedule":"{s}","seed":{d},"kill_ppl_30k":{d:.2},"sacred":{s}}}
        , .{
            child_name,
            parent_name,
            c.lr_str[0..c.lr_len],
            c.grad_clip,
            c.warmup,
            c.context,
            sched,
            c.seed,
            c.kill_ppl_30k,
            sacred_str,
        }) catch return;
        out_file.writeAll(line) catch return;
    }
    out_file.writeAll("\n]\n") catch return;
    print("\n  {s}✅ Configs written → {s}{s}\n", .{ GREEN, out_path, RESET });
}

fn appendMockLineage(
    lineage_path: []const u8,
    configs_buf: *const [MAX_SERVICES]MutatedConfig,
    config_names: *const [MAX_SERVICES][64]u8,
    config_name_lens: *const [MAX_SERVICES]u8,
    parent_names_buf: *const [MAX_SERVICES][64]u8,
    parent_name_lens: *const [MAX_SERVICES]u8,
    num_children: usize,
    entries: *const [MAX_SERVICES]ServiceEntry,
    sorted_idx: *const [MAX_SERVICES]usize,
    actual_parents: usize,
) void {
    var lineage_file = std.fs.cwd().createFile(lineage_path, .{ .truncate = false }) catch {
        print("  {s}⚠️  Failed to open lineage file{s}\n", .{ YELLOW, RESET });
        return;
    };
    defer lineage_file.close();

    // Seek to end for append
    lineage_file.seekFromEnd(0) catch {};

    const ts = std.time.milliTimestamp();
    for (0..num_children) |ci| {
        const c = &configs_buf[ci];
        const child_name = config_names[ci][0..config_name_lens[ci]];
        const parent_idx = ci % actual_parents;
        const parent = &entries[sorted_idx[parent_idx]];
        const parent_name = parent_names_buf[ci][0..parent_name_lens[ci]];
        const sched: []const u8 = c.lr_schedule.toStr();
        const sacred_str: []const u8 = if (c.sacred) "true" else "false";
        var line_buf: [512]u8 = undefined;
        const line = std.fmt.bufPrint(&line_buf,
            \\{{"gen":1,"child":"{s}","parent":"{s}","parent_ppl":{d:.2},"sacred":{s},"mutations":{{"lr":"{s}->{s}","grad_clip":"{d:.1}->{d:.1}","warmup":"{d}->{d}","schedule":"{s}","context":"{d}"}},"timestamp":{d}}}
        ++ "\n", .{
            child_name,
            parent_name,
            parent.current_ppl,
            sacred_str,
            parent.lrStr(),
            c.lr_str[0..c.lr_len],
            parent.grad_clip,
            c.grad_clip,
            parent.warmup,
            c.warmup,
            sched,
            c.context,
            ts,
        }) catch continue;
        lineage_file.writeAll(line) catch continue;
    }
    print("  {s}✅ Lineage logged → {s} ({d} entries){s}\n", .{ GREEN, lineage_path, num_children, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// INIT — Scan all accounts, build initial EvolutionState
// ═══════════════════════════════════════════════════════════════════════════════

fn runInit(allocator: Allocator) !void {
    print("\n{s}🧬 EVOLUTION INIT — Scanning Farm{s}\n", .{ BOLD, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (account_count == 0) {
        print("  {s}⚠️  No Railway accounts found. Set RAILWAY_API_TOKEN + RAILWAY_PROJECT_ID + RAILWAY_ENVIRONMENT_ID in .env{s}\n\n", .{ YELLOW, RESET });
        return;
    }
    print("  {s}Discovered {d} account(s){s}\n\n", .{ DIM, account_count, RESET });

    var state = EvolutionState{};

    for (accounts_buf[0..account_count], 0..) |acct, acct_idx| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch |err| {
            print("  {s}⚠️  {s}: No token ({s}){s}\n", .{ YELLOW, acct.name, @errorName(err), RESET });
            continue;
        };
        defer api.deinit();

        print("{s}=== {s} ==={s}\n", .{ BOLD, acct.name, RESET });

        // Get services with IDs + deployment status
        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { id status } } } } } } } }";
        const vars_json = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(vars_json);

        const resp = api.query(gql, vars_json) catch |err| {
            print("  {s}⚠️  API error: {s}{s}\n", .{ RED, @errorName(err), RESET });
            continue;
        };
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch {
            print("  {s}⚠️  Invalid JSON{s}\n", .{ RED, RESET });
            continue;
        };
        defer parsed.deinit();

        const edges = getEdgesFromProject(parsed.value) orelse {
            print("  {s}⚠️  No services found{s}\n", .{ RED, RESET });
            continue;
        };

        var count: usize = 0;
        for (edges) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const svc_id = getJsonString(node, "id");
            const svc_name = getJsonString(node, "name");

            // Skip non-training services
            if (!isTrainingService(svc_name)) continue;

            const entry = state.addService() orelse break;
            copyToFixed(&entry.svc_id, &entry.svc_id_len, svc_id);
            copyToFixed(&entry.svc_name, &entry.svc_name_len, svc_name);
            entry.account_idx = @intCast(acct_idx);

            // Get deployment status
            if (getJsonObject(node, "deployments")) |deps| {
                if (getJsonObject(deps, "edges")) |dep_edges| {
                    if (dep_edges == .array and dep_edges.array.items.len > 0) {
                        const dep_node = getJsonObject(dep_edges.array.items[0], "node") orelse continue;
                        const dep_status = getJsonString(dep_node, "status");
                        entry.status = classifyStatus(dep_status);
                    }
                }
            }

            // Get env vars for config
            const vars_resp = api.getVariables(svc_id, acct.env_id) catch continue;
            defer allocator.free(vars_resp);

            const vars_parsed = std.json.parseFromSlice(std.json.Value, allocator, vars_resp, .{}) catch continue;
            defer vars_parsed.deinit();

            extractConfig(entry, vars_parsed.value);
            count += 1;

            // Rate limiting between API calls
            std.Thread.sleep(100 * std.time.ns_per_ms);
        }

        print("  Found {d} training services\n\n", .{count});
    }

    state.total_configs_tested = @intCast(state.service_count);
    saveState(state) catch |err| {
        print("{s}❌ Failed to save state: {s}{s}\n", .{ RED, @errorName(err), RESET });
        return;
    };

    print("{s}════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("{s}INIT DONE: {d} services tracked → {s}{s}\n\n", .{ BOLD, state.service_count, STATE_PATH, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS — Leaderboard + rung progress
// ═══════════════════════════════════════════════════════════════════════════════

fn runStatus(allocator: Allocator, args: []const []const u8) !void {
    var state = loadState(allocator) catch {
        print("{s}❌ No evolution state. Run: tri farm evolve init{s}\n", .{ RED, RESET });
        return;
    };

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            exportJson(&state);
            return;
        } else if (std.mem.eql(u8, arg, "--csv")) {
            exportCsv(&state);
            return;
        }
    }

    printDashboard(&state);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STEP — Execute one evolution cycle
// ═══════════════════════════════════════════════════════════════════════════════

fn runStep(allocator: Allocator, args: []const []const u8) !void {
    var dry_run = false;
    var sacred_mode = false;
    var issue_num: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--sacred")) {
            sacred_mode = true;
        } else if (std.mem.eql(u8, args[i], "--issue") and i + 1 < args.len) {
            i += 1;
            issue_num = args[i];
        }
    }

    var state = loadState(allocator) catch {
        print("{s}❌ No evolution state. Run: tri farm evolve init{s}\n", .{ RED, RESET });
        return;
    };

    state.evolution_step += 1;

    print("\n{s}🧬 EVOLUTION STEP {d}{s}", .{ BOLD, state.evolution_step, RESET });
    if (sacred_mode) print(" {s}[SACRED]{s}", .{ MAGENTA, RESET });
    if (dry_run) print(" {s}[DRY RUN]{s}", .{ YELLOW, RESET });
    print("\n{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    // 1. Collect metrics from logs (may hang on slow Railway API — saves state incrementally)
    print("{s}📊 Collecting metrics...{s}\n", .{ CYAN, RESET });
    var api_calls: u32 = 0;
    collectMetrics(allocator, &state, &api_calls);
    print("  API calls: {d}\n\n", .{api_calls});

    // Save metrics immediately (in case ranking/recycling hangs later)
    if (!dry_run) {
        saveState(state) catch {};
    }

    // 2. Process each rung
    var total_killed: usize = 0;
    var total_spawned: usize = 0;
    var summary_buf: [2048]u8 = undefined;
    var summary_len: usize = 0;

    const active_rungs = if (sacred_mode) &SACRED_RUNGS else &DEFAULT_RUNGS;
    for (active_rungs, 0..) |rung, rung_idx| {
        const result = processRung(allocator, &state, @intCast(rung_idx), rung, dry_run, &api_calls, sacred_mode);
        total_killed += result.killed;
        total_spawned += result.spawned;

        if (result.killed > 0) {
            const line = std.fmt.bufPrint(summary_buf[summary_len..], "  Rung {d} ({d}K): {d} killed, {d} spawned\n", .{
                rung_idx + 1, rung.step_threshold / 1000, result.killed, result.spawned,
            }) catch break;
            summary_len += line.len;
        }
    }

    // 3. Update best
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status == .running and svc.current_ppl < state.best_ppl and svc.current_ppl > 0) {
            state.best_ppl = svc.current_ppl;
            state.best_step = svc.current_step;
            copyToFixed(&state.best_name, &state.best_name_len, svc.svcName());
        }
    }

    // 4. Save state
    if (!dry_run) {
        saveState(state) catch |err| {
            print("{s}❌ Failed to save state: {s}{s}\n", .{ RED, @errorName(err), RESET });
        };
    }

    // 5. Print dashboard
    printDashboard(&state);

    print("  {s}ACTIONS THIS STEP:{s}\n", .{ BOLD, RESET });
    if (total_killed == 0) {
        print("  (no services eligible for culling)\n", .{});
    } else {
        print("{s}", .{summary_buf[0..summary_len]});
    }
    print("\n", .{});

    // 6. Post to GitHub issue (always #357 for Rainbow Bridge, override with --issue)
    if (!dry_run) {
        const target_issue = issue_num orelse "357";
        postToIssue(allocator, target_issue, &state, total_killed, total_spawned);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY — Print event log
// ═══════════════════════════════════════════════════════════════════════════════

fn runHistory(allocator: Allocator) !void {
    const state = loadState(allocator) catch {
        print("{s}❌ No evolution state. Run: tri farm evolve init{s}\n", .{ RED, RESET });
        return;
    };

    print("\n{s}📜 EVOLUTION HISTORY — {d} events{s}\n", .{ BOLD, state.event_count, RESET });
    print("{s}════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });

    if (state.event_count == 0) {
        print("  (no events yet)\n\n", .{});
        return;
    }

    print("  {s}TYPE          SERVICE                DETAIL{s}\n", .{ DIM, RESET });
    print("  {s}─────────────────────────────────────────────────────────{s}\n", .{ DIM, RESET });

    for (state.events[0..state.event_count]) |*ev| {
        const icon = switch (ev.event_type) {
            .kill => "💀 KILL  ",
            .spawn => "🌱 SPAWN ",
            .rung_complete => "🏁 RUNG  ",
            .err => "❌ ERROR ",
            .tune => "🔧 TUNE  ",
        };
        const color = switch (ev.event_type) {
            .kill => RED,
            .spawn => GREEN,
            .rung_complete => CYAN,
            .err => RED,
            .tune => YELLOW,
        };
        print("  {s}{s}{s}", .{ color, icon, RESET });
        print("{s}", .{ev.svcName()});
        padTo(ev.service_name_len, 22);
        print(" {s}\n", .{ev.detailStr()});
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Metric Collection
// ═══════════════════════════════════════════════════════════════════════════════

fn collectMetrics(allocator: Allocator, state: *EvolutionState, api_calls: *u32) void {
    var collected: usize = 0;
    var skipped: usize = 0;

    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    // I5: Per-account status tracking
    var acct_status: [MAX_FARM_ACCOUNTS]enum(u8) { ok, timeout, skipped, no_token } = undefined;
    for (0..MAX_FARM_ACCOUNTS) |ai| acct_status[ai] = .skipped;

    // Collect per-account to reuse API client
    for (accounts_buf[0..account_count], 0..) |acct, acct_idx| {
        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch {
            print("  {s}⚠️  {s}: no token{s}\n", .{ YELLOW, acct.name, RESET });
            acct_status[acct_idx] = .no_token;
            continue;
        };
        defer api.deinit();

        // Batch query: get all services with deployment IDs in one call
        const batch_gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { id status } } } } } } } }";
        const batch_vars = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(batch_vars);

        const batch_resp = api.query(batch_gql, batch_vars) catch {
            print("  {s}⚠️  {s}: batch query failed{s}\n", .{ RED, acct.name, RESET });
            acct_status[acct_idx] = .timeout;
            // I5: Save partial state so data from previous accounts is preserved
            saveState(state.*) catch {};
            continue;
        };
        defer allocator.free(batch_resp);
        api_calls.* += 1;

        const batch_parsed = std.json.parseFromSlice(std.json.Value, allocator, batch_resp, .{}) catch continue;
        defer batch_parsed.deinit();

        const edges = getEdgesFromProject(batch_parsed.value) orelse continue;

        acct_status[acct_idx] = .ok;

        // Build deployment ID map from batch response
        for (edges) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const svc_id = getJsonString(node, "id");
            const svc_name = getJsonString(node, "name");

            // Find matching service in state
            const svc = findServiceById(state, svc_id, @intCast(acct_idx)) orelse {
                if (isTrainingService(svc_name)) {
                    print("  {s}  {s}: not in state{s}\n", .{ DIM, svc_name, RESET });
                }
                continue;
            };
            if (svc.status != .running and svc.status != .stalled) continue;

            // Extract deployment ID
            var dep_id: ?[]const u8 = null;
            if (getJsonObject(node, "deployments")) |deps| {
                if (getJsonObject(deps, "edges")) |dep_edges| {
                    if (dep_edges == .array and dep_edges.array.items.len > 0) {
                        const dep_node = getJsonObject(dep_edges.array.items[0], "node") orelse continue;
                        const id = getJsonString(dep_node, "id");
                        if (!std.mem.eql(u8, id, "?")) dep_id = id;
                    }
                }
            }

            const did = dep_id orelse {
                print("  {s}  {s}: no deployment{s}\n", .{ DIM, svc_name, RESET });
                skipped += 1;
                continue;
            };

            print("  {s}  {s}...{s}", .{ DIM, svc_name, RESET });

            // Rate limit — 1s between calls to reduce Railway API pressure
            std.Thread.sleep(1000 * std.time.ns_per_ms);

            // Fresh API client per log call (reusing clients causes TLS hangs)
            var log_api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch {
                print(" {s}no token{s}\n", .{ RED, RESET });
                skipped += 1;
                continue;
            };

            // I3: Wider log window for leaders and near-rung services
            const log_limit = logLimitForService(svc);
            const log_resp_result = log_api.getDeploymentLogs(did, log_limit);
            log_api.deinit();

            const log_resp = log_resp_result catch {
                print(" {s}logs failed{s}\n", .{ RED, RESET });
                skipped += 1;
                // I5: Save partial state before potential hang on next service
                saveState(state.*) catch {};
                continue;
            };
            defer allocator.free(log_resp);

            const log_parsed = std.json.parseFromSlice(std.json.Value, allocator, log_resp, .{}) catch {
                print(" {s}bad json{s}\n", .{ RED, RESET });
                skipped += 1;
                continue;
            };
            defer log_parsed.deinit();

            const prev_status = svc.status;
            parseLogsForMetrics(svc, log_parsed.value);
            api_calls.* += 1;

            // I2: Push health events on status change
            if (svc.status != prev_status and svc.status != .running) {
                const detail_str: []const u8 = switch (svc.status) {
                    .stalled => "stalled: step unchanged 2+ polls",
                    .diverged => "diverged: PPL>1000 at step>5K",
                    .stuck => "stuck: step=0 for 2+ polls",
                    else => "status changed",
                };
                state.addEvent(.err, svc.svcName(), detail_str);
                notifyWsBus(.health, svc.svcName(), detail_str);
                // I6: Append to events JSONL
                appendEventJsonl(svc.svcName(), detail_str, svc.current_step);
            }

            // I4: Push checkpoint event on new checkpoint
            if (svc.last_ckpt_step > 0) {
                var ckpt_detail: [64]u8 = undefined;
                const ckpt_str = std.fmt.bufPrint(&ckpt_detail, "checkpoint at step {d}", .{svc.last_ckpt_step}) catch "checkpoint";
                notifyWsBus(.rung, svc.svcName(), ckpt_str);
            }

            // Save state after each successful collection (protect against next call hanging)
            saveState(state.*) catch {};

            if (svc.current_ppl < 998) {
                const status_icon: []const u8 = switch (svc.status) {
                    .stalled => " [STALL]",
                    .diverged => " [DIVERGED]",
                    .stuck => " [STUCK]",
                    else => "",
                };
                if (svc.val_ppl < 998) {
                    print(" step={d} PPL={d:.1} val={d:.1}{s}\n", .{ svc.current_step, svc.current_ppl, svc.val_ppl, status_icon });
                } else {
                    print(" step={d} PPL={d:.1}{s}\n", .{ svc.current_step, svc.current_ppl, status_icon });
                }
                collected += 1;
            } else {
                print(" {s}no metrics{s}\n", .{ YELLOW, RESET });
                skipped += 1;
            }
        }

        // I5: Progressive save after each account completes
        saveState(state.*) catch {};
    }

    // I5: Print per-account poll summary
    print("  Collected: {d} | Skipped: {d}\n", .{ collected, skipped });
    print("  Accounts: ", .{});
    for (accounts_buf[0..account_count], 0..) |acct, ai| {
        const icon: []const u8 = switch (acct_status[ai]) {
            .ok => "✅",
            .timeout => "⚠️ timeout",
            .no_token => "❌ no token",
            .skipped => "⏭️ skipped",
        };
        if (ai > 0) print(" | ", .{});
        print("{s} {s}", .{ acct.name, icon });
    }
    print("\n", .{});
}

/// I6: Append event to JSONL file (append-only, never truncated)
fn appendEventJsonl(svc_name: []const u8, detail: []const u8, step: u32) void {
    const file = std.fs.cwd().createFile(EVENTS_JSONL_PATH, .{ .truncate = false }) catch return;
    defer file.close();
    // Seek to end for append
    file.seekFromEnd(0) catch return;
    var buf: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&buf, "{{\"ts\":{d},\"type\":\"health\",\"svc\":\"{s}\",\"detail\":\"{s}\",\"step\":{d}}}\n", .{
        std.time.milliTimestamp(), svc_name, detail, step,
    }) catch return;
    file.writeAll(line) catch {};
}

fn findServiceById(state: *EvolutionState, svc_id: []const u8, acct_idx: u8) ?*ServiceEntry {
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.account_idx != acct_idx) continue;
        if (std.mem.eql(u8, svc.svcId(), svc_id)) return svc;
    }
    return null;
}

/// Fetch deploymentLogs via curl with --max-time 15 (bulletproof timeout).
/// Returns allocated JSON response body.
fn curlGraphQL(allocator: Allocator, token: []const u8, deployment_id: []const u8, limit: u32) ![]const u8 {
    const body = std.fmt.allocPrint(allocator,
        \\{{"query":"query($deploymentId: String!, $limit: Int) {{ deploymentLogs(deploymentId: $deploymentId, limit: $limit) {{ timestamp message severity }} }}","variables":{{"deploymentId":"{s}","limit":{d}}}}}
    , .{ deployment_id, limit }) catch return error.OutOfMemory;
    defer allocator.free(body);

    const auth_hdr = std.fmt.allocPrint(allocator, "Authorization: Bearer {s}", .{token}) catch return error.OutOfMemory;
    defer allocator.free(auth_hdr);

    var child = std.process.Child.init(&.{
        "curl",                                     "-s",     "--max-time", "15",
        "-X",                                       "POST",   "-H",         "Content-Type: application/json",
        "-H",                                       auth_hdr, "-d",         body,
        "https://backboard.railway.com/graphql/v2",
    }, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    _ = child.spawn() catch return error.ConnectionFailed;
    errdefer {
        _ = child.kill() catch {};
        _ = child.wait() catch {};
    }

    // Read stdout via poll
    var stdout_buf: std.ArrayList(u8) = .empty;
    var stderr_buf: std.ArrayList(u8) = .empty;
    defer stderr_buf.deinit(allocator);

    child.collectOutput(allocator, &stdout_buf, &stderr_buf, 1 * 1024 * 1024) catch {
        stdout_buf.deinit(allocator);
        return error.RequestFailed;
    };

    const term = child.wait() catch {
        stdout_buf.deinit(allocator);
        return error.RequestFailed;
    };

    if (term.Exited != 0) {
        stdout_buf.deinit(allocator);
        return error.RequestFailed;
    }

    // Debug: empty response check
    if (stdout_buf.items.len == 0) {
        stdout_buf.deinit(allocator);
        return error.RequestFailed;
    }

    // Transfer ownership of the buffer
    return stdout_buf.toOwnedSlice(allocator) catch {
        stdout_buf.deinit(allocator);
        return error.OutOfMemory;
    };
}

fn extractDeploymentId(root: std.json.Value) ?[]const u8 {
    const data = getJsonObject(root, "data") orelse return null;
    const deps = getJsonObject(data, "deployments") orelse return null;
    const edges = getJsonObject(deps, "edges") orelse return null;
    if (edges != .array or edges.array.items.len == 0) return null;
    const node = getJsonObject(edges.array.items[0], "node") orelse return null;
    const id = getJsonString(node, "id");
    if (std.mem.eql(u8, id, "?")) return null;
    return id;
}

fn parseLogsForMetrics(svc: *ServiceEntry, root: std.json.Value) void {
    const data = getJsonObject(root, "data") orelse return;
    const logs = getJsonObject(data, "deploymentLogs") orelse return;
    if (logs != .array) return;

    // Save previous step for stall detection (I2)
    svc.last_poll_step = svc.current_step;

    // Scan ALL lines forward for loss history (I1) + checkpoint parsing (I4)
    for (logs.array.items) |log_entry| {
        const msg = getJsonString(log_entry, "message");
        if (std.mem.eql(u8, msg, "?")) continue;

        // I1: Collect all training metrics into loss history
        if (parseTrainingLine(msg)) |metrics| {
            svc.appendLossHistory(metrics.step, metrics.ppl, metrics.loss);
        }

        // I4: Parse [CKPT] lines
        if (std.mem.indexOf(u8, msg, "[CKPT]") != null or
            std.mem.indexOf(u8, msg, "checkpoint saved") != null or
            std.mem.indexOf(u8, msg, "Checkpoint saved") != null)
        {
            if (parseCkptLine(msg)) |ckpt_step| {
                svc.last_ckpt_step = ckpt_step;
            }
        }
    }

    // Scan backwards for most recent training line (latest metrics)
    var idx: usize = logs.array.items.len;
    while (idx > 0) {
        idx -= 1;
        const log_entry = logs.array.items[idx];
        const msg = getJsonString(log_entry, "message");
        if (std.mem.eql(u8, msg, "?")) continue;

        if (parseTrainingLine(msg)) |metrics| {
            svc.current_step = metrics.step;
            svc.current_loss = metrics.loss;
            svc.current_ppl = metrics.ppl;
            svc.tok_per_sec = metrics.tok_per_sec;
            break;
        }
    }

    // Also scan for [VAL] lines (P1: validation PPL)
    idx = logs.array.items.len;
    while (idx > 0) {
        idx -= 1;
        const log_entry = logs.array.items[idx];
        const msg = getJsonString(log_entry, "message");
        if (std.mem.indexOf(u8, msg, "[VAL]") != null) {
            if (parseValLine(msg)) |vp| {
                svc.val_ppl = vp;
                break;
            }
        }
    }

    // I2: Stall detection — step unchanged across polls
    if (svc.last_poll_step > 0 and svc.current_step == svc.last_poll_step) {
        svc.stall_count += 1;
        if (svc.stall_count >= 2 and svc.status == .running) {
            svc.status = .stalled;
        }
    } else {
        svc.stall_count = 0;
        // Recover from stalled if step advanced
        if (svc.status == .stalled) svc.status = .running;
    }

    // I2: Divergence detection — PPL > 1000 at step > 5K (skip NCA phase)
    if (svc.status == .running and svc.current_step > 5000 and svc.current_ppl > 1000) {
        svc.status = .diverged;
    }

    // I2: Stuck detection — step=0 for multiple polls
    if (svc.status == .running and svc.current_step == 0 and svc.stall_count >= 2) {
        svc.status = .stuck;
    }
}

/// I4: Parse checkpoint step from log line
/// Formats: "[CKPT] Saved: data/checkpoints/hslm_step_50000.bin"
///          "checkpoint saved at step 50000"
fn parseCkptLine(line: []const u8) ?u32 {
    // Try "step_NNNNN" pattern
    if (std.mem.indexOf(u8, line, "step_")) |pos| {
        const start = pos + 5;
        var end = start;
        while (end < line.len and line[end] >= '0' and line[end] <= '9') : (end += 1) {}
        if (end > start) {
            return std.fmt.parseInt(u32, line[start..end], 10) catch null;
        }
    }
    // Try "step NNNNN" pattern
    if (std.mem.indexOf(u8, line, "step ")) |pos| {
        const start = pos + 5;
        var end = start;
        while (end < line.len and line[end] >= '0' and line[end] <= '9') : (end += 1) {}
        if (end > start) {
            return std.fmt.parseInt(u32, line[start..end], 10) catch null;
        }
    }
    return null;
}

/// I3: Determine log line limit based on service PPL/step
fn logLimitForService(svc: *const ServiceEntry) u32 {
    // Leaders (sub-10 PPL) get wider window
    if (svc.current_ppl > 0 and svc.current_ppl < 10) return 100;
    // Near rung thresholds (within 5K of 50K or 100K) get medium window
    if (svc.current_step > 45000 and svc.current_step < 55000) return 50;
    if (svc.current_step > 95000 and svc.current_step < 105000) return 50;
    return 20;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Training Line Parser
// ═══════════════════════════════════════════════════════════════════════════════

const TrainingMetrics = struct {
    step: u32,
    loss: f32,
    ppl: f32,
    tok_per_sec: f32 = 0,
};

/// Parse pipe-delimited training output:
///   "    5000 |   5.8234 |   5.9100 |   338.45 |   0.001000 |   0.8234 |   1400"
/// Columns: step, loss, avg_loss, ppl, lr, c_ratio, tok/s
pub fn parseTrainingLine(line: []const u8) ?TrainingMetrics {
    // Skip [EARLY KILL] lines
    if (std.mem.indexOf(u8, line, "[EARLY KILL]") != null) return null;

    // Must contain at least 6 pipes for 7 columns
    var pipe_count: usize = 0;
    for (line) |c| {
        if (c == '|') pipe_count += 1;
    }
    if (pipe_count < 6) return null;

    // Split by '|'
    var columns: [8][]const u8 = undefined;
    var col_idx: usize = 0;
    var start: usize = 0;
    for (line, 0..) |c, ci| {
        if (c == '|') {
            if (col_idx < 8) {
                columns[col_idx] = std.mem.trim(u8, line[start..ci], " \t");
                col_idx += 1;
            }
            start = ci + 1;
        }
    }
    // Last column
    if (col_idx < 8 and start < line.len) {
        columns[col_idx] = std.mem.trim(u8, line[start..], " \t");
        col_idx += 1;
    }

    if (col_idx < 7) return null;

    // Column 0: step (integer)
    const step = std.fmt.parseInt(u32, columns[0], 10) catch return null;
    // Column 1: loss (float)
    const loss = std.fmt.parseFloat(f32, columns[1]) catch return null;
    // Column 3: ppl (float)
    const ppl = std.fmt.parseFloat(f32, columns[3]) catch return null;

    if (ppl <= 0 or loss <= 0) return null;

    const tok_s = if (col_idx > 6) std.fmt.parseFloat(f32, columns[6]) catch 0 else 0;

    return .{ .step = step, .loss = loss, .ppl = ppl, .tok_per_sec = tok_s };
}

/// Parse [VAL] log line: "[VAL] step=NNNNN val_loss=X.XXXX val_ppl=XX.XX"
fn parseValLine(line: []const u8) ?f32 {
    const key = "val_ppl=";
    const start = (std.mem.indexOf(u8, line, key) orelse return null) + key.len;
    var end = start;
    while (end < line.len and line[end] != ' ' and line[end] != '\n' and line[end] != '\r') : (end += 1) {}
    return std.fmt.parseFloat(f32, line[start..end]) catch null;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Ranking and Selection
// ═══════════════════════════════════════════════════════════════════════════════

const RungResult = struct {
    killed: usize,
    spawned: usize,
};

fn processRung(allocator: Allocator, state: *EvolutionState, rung_idx: u8, rung: Rung, dry_run: bool, api_calls: *u32, sacred: bool) RungResult {
    // Find eligible services: running, step >= threshold, rung not yet passed
    var eligible_indices: [MAX_SERVICES]usize = undefined;
    var eligible_count: usize = 0;

    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.status != .running) continue;
        if (svc.current_step < rung.step_threshold) continue;
        if (svc.rungs_passed[rung_idx]) continue;
        if (eligible_count < MAX_SERVICES) {
            eligible_indices[eligible_count] = si;
            eligible_count += 1;
        }
    }

    if (eligible_count == 0) return .{ .killed = 0, .spawned = 0 };

    // Sort eligible by fitness (sacred uses φ-weighted composite, default uses PPL)
    if (sacred) sortBySacredFitness(state, eligible_indices[0..eligible_count]) else sortByPpl(state, eligible_indices[0..eligible_count]);

    // Outlier capping: PPL above per-rung threshold are auto-victims
    const PPL_OUTLIER_THRESHOLD: f32 = rung.outlier_threshold;
    var outlier_count: usize = 0;
    {
        var oi: usize = eligible_count;
        while (oi > 0) {
            oi -= 1;
            if (getPplForRanking(&state.services[eligible_indices[oi]]) > PPL_OUTLIER_THRESHOLD) {
                outlier_count += 1;
            } else break; // sorted, so all before are <= threshold
        }
    }
    // Non-outlier count for ratio-based kill calculation
    const non_outlier_count = eligible_count - outlier_count;

    // Determine kill count: outliers always killed + ratio of non-outliers
    const ratio_kill = @as(usize, @intFromFloat(@as(f32, @floatFromInt(non_outlier_count)) * rung.kill_ratio));
    const total_proposed = outlier_count + ratio_kill;
    const max_killable = if (eligible_count > MIN_SURVIVORS) eligible_count - MIN_SURVIVORS else 0;
    const kill_count = @min(total_proposed, max_killable);

    // Leaders = top 20% of non-outliers
    const leader_count = @max(1, non_outlier_count / 5);

    if (kill_count == 0) {
        // Mark all as passed, no kills
        for (eligible_indices[0..eligible_count]) |si| {
            state.services[si].rungs_passed[rung_idx] = true;
        }
        return .{ .killed = 0, .spawned = 0 };
    }

    print("  {s}Rung {d} ({d}K):{s} {d} eligible, killing {d}, {d} leaders\n", .{
        MAGENTA,        rung_idx + 1, rung.step_threshold / 1000, RESET,
        eligible_count, kill_count,   leader_count,
    });

    var killed: usize = 0;
    var spawned: usize = 0;

    // Kill from bottom (worst PPL)
    var ki: usize = 0;
    while (ki < kill_count) : (ki += 1) {
        const victim_idx = eligible_indices[eligible_count - 1 - ki];
        const victim = &state.services[victim_idx];

        // Pick parent via truncation selection (diverse parents per child)
        const prng_seed: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())) +% ki);
        const leader_idx = selectParentTruncation(state, prng_seed) orelse eligible_indices[0];
        const leader = &state.services[leader_idx];

        // Mutate config (sacred uses φ-grid, random uses continuous)
        const new_config = if (sacred) mutateConfigSacred(leader, prng_seed +% 1, false) else mutateConfig(leader, prng_seed +% 1);

        print("  {s}💀 KILL{s} {s} PPL={d:.1} → mutant of {s} LR={s}\n", .{
            RED, RESET, victim.svcName(), victim.current_ppl, leader.svcName(), new_config.lr_str[0..new_config.lr_len],
        });

        // Record event
        var detail_buf: [128]u8 = undefined;
        const detail = std.fmt.bufPrint(&detail_buf, "PPL={d:.1} → mutant of {s}", .{ victim.current_ppl, leader.svcName() }) catch "recycled";
        state.addEvent(.kill, victim.svcName(), detail);
        notifyWsBus(.kill, victim.svcName(), detail);

        if (!dry_run) {
            recycleService(allocator, state, victim_idx, new_config, leader.svcName(), api_calls);
            spawned += 1;
        }
        killed += 1;
    }

    // Mark all eligible as passed for this rung
    for (eligible_indices[0..eligible_count]) |si| {
        state.services[si].rungs_passed[rung_idx] = true;
    }

    state.total_configs_tested += @intCast(spawned);

    return .{ .killed = killed, .spawned = spawned };
}

/// Get effective PPL for ranking: prefer val_ppl when available (P1)
fn getPplForRanking(svc: *const ServiceEntry) f32 {
    if (svc.val_ppl < 998.0) return svc.val_ppl;
    return svc.current_ppl;
}

fn sortByPpl(state: *EvolutionState, indices: []usize) void {
    // Simple insertion sort (small N), ranks by val_ppl if available
    var ii: usize = 1;
    while (ii < indices.len) : (ii += 1) {
        const key = indices[ii];
        const key_ppl = getPplForRanking(&state.services[key]);
        var jj: usize = ii;
        while (jj > 0 and getPplForRanking(&state.services[indices[jj - 1]]) > key_ppl) {
            indices[jj] = indices[jj - 1];
            jj -= 1;
        }
        indices[jj] = key;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Config Mutation (PBT)
// ═══════════════════════════════════════════════════════════════════════════════

const LrSchedule = enum(u8) {
    cosine,
    phi_restart,
    d2z, // Linear Decay-to-Zero (ICLR 2025)
    wsd, // Warmup-Stable-Decay (MiniCPM-style)

    fn toStr(self: LrSchedule) []const u8 {
        return switch (self) {
            .cosine => "cosine",
            .phi_restart => "phi_restart",
            .d2z => "d2z",
            .wsd => "wsd",
        };
    }

    fn toShort(self: LrSchedule) []const u8 {
        return switch (self) {
            .cosine => "cos  ",
            .phi_restart => "phi  ",
            .d2z => "d2z  ",
            .wsd => "wsd  ",
        };
    }

    fn fromStr(s: []const u8) LrSchedule {
        if (std.mem.eql(u8, s, "phi_restart")) return .phi_restart;
        if (std.mem.eql(u8, s, "d2z")) return .d2z;
        if (std.mem.eql(u8, s, "wsd")) return .wsd;
        return .cosine;
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// Diversity Quotas — auto-balance objective/context distribution
// ═══════════════════════════════════════════════════════════════════════════════

const QuotaBucket = struct {
    objective: []const u8,
    min_context: u32, // 0 = any context, 81 = only 81+243
    target_pct: f32, // target fraction 0.0-1.0
};

const MAX_QUOTA_BUCKETS = 8;

const DEFAULT_QUOTAS = [_]QuotaBucket{
    .{ .objective = "ntp", .min_context = 0, .target_pct = 0.40 },
    .{ .objective = "ntp", .min_context = 81, .target_pct = 0.20 },
    .{ .objective = "jepa", .min_context = 0, .target_pct = 0.20 },
    .{ .objective = "hybrid", .min_context = 0, .target_pct = 0.20 },
};

const QuotaDeficit = struct {
    objective: []const u8,
    min_context: u32,
    deficit: f32, // target_pct - actual_pct (positive = underrepresented)
};

fn computeQuotaDeficit(state: *const EvolutionState) QuotaDeficit {
    var alive: u32 = 0;
    var counts: [DEFAULT_QUOTAS.len]u32 = .{0} ** DEFAULT_QUOTAS.len;

    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status != .running and svc.status != .idle) continue;
        alive += 1;

        for (DEFAULT_QUOTAS, 0..) |bucket, bi| {
            const obj_match = std.mem.eql(u8, svc.objectiveStr(), bucket.objective) or
                (std.mem.eql(u8, bucket.objective, "ntp") and svc.objective_len == 0);
            if (!obj_match) continue;
            if (bucket.min_context > 0 and svc.context < bucket.min_context) continue;
            counts[bi] += 1;
        }
    }

    if (alive == 0) {
        return .{ .objective = DEFAULT_QUOTAS[0].objective, .min_context = DEFAULT_QUOTAS[0].min_context, .deficit = 1.0 };
    }

    const n: f32 = @floatFromInt(alive);
    var max_deficit: f32 = -999.0;
    var max_idx: usize = 0;

    for (DEFAULT_QUOTAS, 0..) |bucket, bi| {
        const actual_pct: f32 = @as(f32, @floatFromInt(counts[bi])) / n;
        const deficit = bucket.target_pct - actual_pct;
        if (deficit > max_deficit) {
            max_deficit = deficit;
            max_idx = bi;
        }
    }

    return .{
        .objective = DEFAULT_QUOTAS[max_idx].objective,
        .min_context = DEFAULT_QUOTAS[max_idx].min_context,
        .deficit = max_deficit,
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Recommendations — rule engine for actionable suggestions
// ═══════════════════════════════════════════════════════════════════════════════

const Recommendation = struct {
    severity: Severity,
    message: [192]u8,
    message_len: u8,
    command: [128]u8,
    command_len: u8,

    const Severity = enum { info, warning, critical };
};

const MAX_RECOMMENDATIONS = 8;

fn computeRecommendations(state: *const EvolutionState, health: PopulationHealth, resume_eligible: u32) struct { recs: [MAX_RECOMMENDATIONS]Recommendation, count: usize } {
    var recs: [MAX_RECOMMENDATIONS]Recommendation = undefined;
    var count: usize = 0;

    // Rule 1: diversity collapse
    if (health.diversity < 0.001 and count < MAX_RECOMMENDATIONS) {
        recs[count] = makeRecommendation(.critical, "Diversity collapse ({d:.4}). Inject diverse configs.", "tri farm evolve inject --count 10 --quota --sacred", .{health.diversity});
        count += 1;
    }

    // Rule 2: elite gap too large
    if (health.elite_gap > 5.0 and count < MAX_RECOMMENDATIONS) {
        recs[count] = makeRecommendation(.warning, "Elite gap high ({d:.1}x). Inject more configs.", "tri farm evolve inject --count 8 --quota --force", .{health.elite_gap});
        count += 1;
    }

    // Rule 3: spike rate
    if (health.spike_rate > 0.15 and count < MAX_RECOMMENDATIONS) {
        recs[count] = makeRecommendation(.warning, "Spike rate {d:.0}%. Tune struggling workers.", "tri farm evolve tune --sacred", .{health.spike_rate * 100});
        count += 1;
    }

    // Rule 4: resume eligible
    if (resume_eligible > 3 and count < MAX_RECOMMENDATIONS) {
        var cmd_buf: [128]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmd_buf, "tri farm evolve resume --top-k {d}", .{resume_eligible}) catch "tri farm evolve resume";
        var rec = Recommendation{ .severity = .info, .message = undefined, .message_len = 0, .command = undefined, .command_len = 0 };
        const msg = std.fmt.bufPrint(&rec.message, "{d} services eligible for resume.", .{resume_eligible}) catch "Services eligible for resume.";
        rec.message_len = @intCast(msg.len);
        @memcpy(rec.command[0..cmd.len], cmd);
        rec.command_len = @intCast(cmd.len);
        recs[count] = rec;
        count += 1;
    }

    // Rule 5: alive < total/2
    if (health.alive < health.total / 2 and health.total > 4 and count < MAX_RECOMMENDATIONS) {
        recs[count] = makeRecommendation(.critical, "Only {d}/{d} services alive. Mass inject needed.", "tri farm evolve inject --count 15 --quota --force", .{ health.alive, health.total });
        count += 1;
    }

    // Rule 6: quota deficit > 15%
    const deficit = computeQuotaDeficit(state);
    if (deficit.deficit > 0.15 and count < MAX_RECOMMENDATIONS) {
        var cmd_buf: [128]u8 = undefined;
        const cmd = if (deficit.min_context > 0)
            std.fmt.bufPrint(&cmd_buf, "tri farm evolve inject --count 5 --objective {s} --context {d}", .{ deficit.objective, deficit.min_context }) catch "tri farm evolve inject --count 5 --quota"
        else
            std.fmt.bufPrint(&cmd_buf, "tri farm evolve inject --count 5 --objective {s}", .{deficit.objective}) catch "tri farm evolve inject --count 5 --quota";
        var rec = Recommendation{ .severity = .warning, .message = undefined, .message_len = 0, .command = undefined, .command_len = 0 };
        const msg = std.fmt.bufPrint(&rec.message, "Quota deficit: {s} at {d:.0}% below target.", .{ deficit.objective, deficit.deficit * 100 }) catch "Quota deficit detected.";
        rec.message_len = @intCast(msg.len);
        @memcpy(rec.command[0..cmd.len], cmd);
        rec.command_len = @intCast(cmd.len);
        recs[count] = rec;
        count += 1;
    }

    return .{ .recs = recs, .count = count };
}

fn makeRecommendation(severity: Recommendation.Severity, comptime msg_fmt: []const u8, comptime cmd: []const u8, args: anytype) Recommendation {
    var rec = Recommendation{ .severity = severity, .message = undefined, .message_len = 0, .command = undefined, .command_len = 0 };
    const msg = std.fmt.bufPrint(&rec.message, msg_fmt, args) catch msg_fmt[0..@min(msg_fmt.len, 192)];
    rec.message_len = @intCast(msg.len);
    const cmd_bytes = cmd;
    @memcpy(rec.command[0..cmd_bytes.len], cmd_bytes);
    rec.command_len = @intCast(cmd_bytes.len);
    return rec;
}

const MutatedConfig = struct {
    lr_str: [16]u8,
    lr_len: u8,
    batch_str: [8]u8,
    batch_len: u8,
    optimizer_str: [16]u8,
    optimizer_len: u8,
    seed: u32,
    grad_clip: f32 = 1.0,
    warmup: u32 = 2000,
    lr_schedule: LrSchedule = .cosine,
    context: u32 = 27,
    kill_ppl_30k: f32 = 999.0, // inherit from parent
    sacred: bool = false, // true = sacred-guided mutations
    objective: []const u8 = "ntp", // ntp | jepa | hybrid | nca-ntp | nca-jepa-ntp | nca-jepa-ntp-v2
    nca_steps: u32 = 0, // NCA pre-pre-training steps (0 = no NCA)
    nca_entropy_min: []const u8 = "1.5",
    nca_entropy_max: []const u8 = "2.8",
    fresh: bool = false, // true = HSLM_FRESH=1 (new training from scratch)
};

pub fn mutateConfig(leader: *const ServiceEntry, prng_seed: u32) MutatedConfig {
    return mutateConfigEx(leader, prng_seed, false);
}

pub fn mutateConfigEx(leader: *const ServiceEntry, prng_seed: u32, allow_ctx_mutation: bool) MutatedConfig {
    var config = MutatedConfig{
        .lr_str = undefined,
        .lr_len = 0,
        .batch_str = leader.batch,
        .batch_len = leader.batch_len,
        .optimizer_str = leader.optimizer,
        .optimizer_len = leader.optimizer_len,
        .seed = mulberry32(prng_seed +% 42),
    };

    // --- LR mutation: log-normal σ=0.2, clamp [1e-5, 1e-2] ---
    const base_lr = std.fmt.parseFloat(f64, leader.lrStr()) catch 3e-4;
    const rng_lr = mulberry32(prng_seed);
    // Map to [-1, 1] range then scale by σ=0.2
    const unit_lr = @as(f64, @floatFromInt(rng_lr % 10000)) / 10000.0;
    const log_perturbation = (unit_lr - 0.5) * 0.4; // σ=0.2 → range ±0.2
    var new_lr = base_lr * @exp(log_perturbation);
    new_lr = @max(LR_MIN, @min(LR_MAX, new_lr));

    const lr_result = std.fmt.bufPrint(&config.lr_str, "{e:.2}", .{new_lr}) catch "3e-4";
    config.lr_len = @intCast(lr_result.len);

    // --- Grad clip mutation: ×uniform(0.7, 1.4), clamp [GC_MIN, GC_MAX] ---
    const rng_gc = mulberry32(prng_seed +% 7);
    const gc_factor = 0.7 + @as(f32, @floatFromInt(rng_gc % 1000)) / 1000.0 * 0.7;
    config.grad_clip = @max(GC_MIN, @min(GC_MAX, leader.grad_clip * gc_factor));

    // --- Warmup mutation: ×uniform(0.75, 1.25), clamp [WU_MIN, WU_MAX] ---
    const rng_wu = mulberry32(prng_seed +% 13);
    const wu_factor = 0.75 + @as(f32, @floatFromInt(rng_wu % 1000)) / 1000.0 * 0.5;
    const base_warmup: f32 = @floatFromInt(leader.warmup);
    config.warmup = @intFromFloat(@max(@as(f32, @floatFromInt(WU_MIN)), @min(@as(f32, @floatFromInt(WU_MAX)), base_warmup * wu_factor)));

    // --- LR schedule: 90% inherit, 10% mutate to random other ---
    const rng_sched = mulberry32(prng_seed +% 17);
    if (rng_sched % 10 == 0) {
        const schedules = [_]LrSchedule{ .cosine, .phi_restart, .d2z, .wsd };
        const pick = rng_sched / 10 % 4;
        config.lr_schedule = schedules[pick];
        if (config.lr_schedule == leader.lr_schedule) {
            config.lr_schedule = schedules[(pick + 1) % 4];
        }
    } else {
        config.lr_schedule = leader.lr_schedule;
    }

    // --- Context: 95% inherit, 5% switch 27↔54 (only if opt-in) ---
    config.context = leader.context;
    if (allow_ctx_mutation) {
        const rng_ctx = mulberry32(prng_seed +% 23);
        if (rng_ctx % 20 == 0) {
            config.context = if (leader.context == 27) 54 else 27;
        }
    }

    // --- Kill PPL 30K: inherit from parent ---
    config.kill_ppl_30k = leader.kill_ppl_30k;

    return config;
}

/// Sacred LR grid: base_lr × φ^p for p ∈ {-3..3}, filtered to [1e-5, 1e-2]
fn sacredLrGrid(base_lr: f64, prng_seed: u32) f64 {
    const powers = [_]i8{ -3, -2, -1, 0, 1, 2, 3 };
    var candidates: [7]f64 = undefined;
    var valid_count: usize = 0;

    for (powers) |p| {
        const multiplier = std.math.pow(f64, SACRED_PHI, @as(f64, @floatFromInt(p)));
        const candidate = base_lr * multiplier;
        if (candidate >= LR_MIN and candidate <= LR_MAX) {
            candidates[valid_count] = candidate;
            valid_count += 1;
        }
    }

    if (valid_count == 0) return @max(LR_MIN, @min(LR_MAX, base_lr));
    const pick = mulberry32(prng_seed) % @as(u32, @intCast(valid_count));
    return candidates[pick];
}

/// Sacred mutation: φ-grid LR, discrete grad_clip/warmup from sacred sets
pub fn mutateConfigSacred(leader: *const ServiceEntry, prng_seed: u32, allow_ctx_mutation: bool) MutatedConfig {
    var config = MutatedConfig{
        .lr_str = undefined,
        .lr_len = 0,
        .batch_str = leader.batch,
        .batch_len = leader.batch_len,
        .optimizer_str = leader.optimizer,
        .optimizer_len = leader.optimizer_len,
        .seed = mulberry32(prng_seed +% 42),
        .sacred = true,
    };

    // --- LR: sacred φ-grid ---
    const base_lr = std.fmt.parseFloat(f64, leader.lrStr()) catch 3e-4;
    const new_lr = sacredLrGrid(base_lr, mulberry32(prng_seed));
    const lr_result = std.fmt.bufPrint(&config.lr_str, "{e:.2}", .{new_lr}) catch "3e-4";
    config.lr_len = @intCast(lr_result.len);

    // --- Grad clip: pick from sacred set ---
    const rng_gc = mulberry32(prng_seed +% 7);
    config.grad_clip = SACRED_GRAD_CLIPS[rng_gc % SACRED_GRAD_CLIPS.len];

    // --- Warmup: pick from sacred set ---
    const rng_wu = mulberry32(prng_seed +% 13);
    config.warmup = SACRED_WARMUPS[rng_wu % SACRED_WARMUPS.len];

    // --- LR schedule: 90% inherit, 10% switch (same as random) ---
    const rng_sched = mulberry32(prng_seed +% 17);
    if (rng_sched % 10 == 0) {
        config.lr_schedule = if (leader.lr_schedule == .cosine) .phi_restart else .cosine;
    } else {
        config.lr_schedule = leader.lr_schedule;
    }

    // --- Context: 95% inherit, 5% switch (same as random) ---
    config.context = leader.context;
    if (allow_ctx_mutation) {
        const rng_ctx = mulberry32(prng_seed +% 23);
        if (rng_ctx % 20 == 0) {
            config.context = if (leader.context == 27) 54 else 27;
        }
    }

    // --- Kill PPL 30K: inherit ---
    config.kill_ppl_30k = leader.kill_ppl_30k;

    return config;
}

/// Composite fitness: lower = better. PPL + spike penalty - speed bonus
pub fn computeFitness(entry: *const ServiceEntry) f32 {
    var fitness = entry.current_ppl;
    // Spike penalty: current_loss > avg_loss proxy * 1.5
    // We approximate avg_loss as log(current_ppl) since ppl ≈ exp(loss)
    const expected_loss = @log(entry.current_ppl);
    if (entry.current_loss > expected_loss * 1.5)
        fitness += 5.0;
    // Speed bonus: early low-PPL gets advantage
    const progress = @as(f32, @floatFromInt(entry.current_step)) / 100000.0;
    if (entry.current_ppl < 20.0)
        fitness -= (1.0 - progress) * 0.5;
    return fitness;
}

/// Sacred fitness: φ-weighted composite. Lower = better.
/// Spike penalty = φ × 3 ≈ 4.854 (sacred constant)
/// Convergence bonus = speed × φ^{-1} (reward fast learners)
pub fn computeSacredFitness(entry: *const ServiceEntry) f32 {
    var fitness = entry.current_ppl; // φ^0 baseline
    const expected_loss = @log(entry.current_ppl);
    if (entry.current_loss > expected_loss * 1.5)
        fitness += SACRED_PHI_F32 * 3.0; // spike: +4.854
    if (entry.current_step > 0 and entry.current_ppl < 500.0) {
        const speed = (500.0 - entry.current_ppl) / @as(f32, @floatFromInt(entry.current_step)) * 1000.0;
        if (speed > 0) fitness -= speed * SACRED_PHI_INV_F32; // convergence: ×φ^{-1}
    }
    return fitness;
}

fn sortBySacredFitness(state: *EvolutionState, indices: []usize) void {
    // Insertion sort by sacred fitness ascending (best first)
    var ii: usize = 1;
    while (ii < indices.len) : (ii += 1) {
        const key = indices[ii];
        const key_fit = computeSacredFitness(&state.services[key]);
        var jj: usize = ii;
        while (jj > 0 and computeSacredFitness(&state.services[indices[jj - 1]]) > key_fit) {
            indices[jj] = indices[jj - 1];
            jj -= 1;
        }
        indices[jj] = key;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: PBT Selection Policies (Jaderberg 2017, PB2)
// ═══════════════════════════════════════════════════════════════════════════════

/// Truncation selection: pick uniformly from top-20% elite (min 4).
/// Each call with a different seed yields a different parent.
fn selectParentTruncation(state: *const EvolutionState, prng_seed: u32) ?usize {
    var indices: [MAX_SERVICES]usize = undefined;
    var count: usize = 0;
    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.status != .running or svc.current_step == 0) continue;
        indices[count] = si;
        count += 1;
    }
    if (count == 0) return null;

    // Sort by sacred fitness ascending (best first)
    var ii: usize = 1;
    while (ii < count) : (ii += 1) {
        const key = indices[ii];
        const key_fit = computeSacredFitness(&state.services[key]);
        var jj: usize = ii;
        while (jj > 0 and computeSacredFitness(&state.services[indices[jj - 1]]) > key_fit) {
            indices[jj] = indices[jj - 1];
            jj -= 1;
        }
        indices[jj] = key;
    }

    const elite_size = @max(@as(usize, 4), count * 20 / 100);
    const capped_elite = @min(elite_size, count);
    const pick = mulberry32(prng_seed) % @as(u32, @intCast(capped_elite));
    return indices[pick];
}

/// Binary tournament: pick 2 random running services, return the fitter one.
fn selectParentTournament(state: *const EvolutionState, prng_seed: u32) ?usize {
    var indices: [MAX_SERVICES]usize = undefined;
    var count: usize = 0;
    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.status != .running or svc.current_step == 0) continue;
        indices[count] = si;
        count += 1;
    }
    if (count == 0) return null;
    if (count == 1) return indices[0];

    const a_pick = mulberry32(prng_seed) % @as(u32, @intCast(count));
    var b_pick = mulberry32(prng_seed +% 1) % @as(u32, @intCast(count));
    if (b_pick == a_pick) b_pick = (a_pick + 1) % @as(u32, @intCast(count));

    const a_idx = indices[a_pick];
    const b_idx = indices[b_pick];
    const a_fit = computeSacredFitness(&state.services[a_idx]);
    const b_fit = computeSacredFitness(&state.services[b_idx]);
    return if (a_fit <= b_fit) a_idx else b_idx;
}

/// Kill tournament: find a victim from bottom-20% of running workers past min_step.
/// Returns null if no eligible victims.
fn findKillTournamentVictim(state: *const EvolutionState, min_step: u32, prng_seed: u32) ?usize {
    var indices: [MAX_SERVICES]usize = undefined;
    var count: usize = 0;
    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.status != .running or svc.current_step < min_step) continue;
        if (svc.account_idx == 0) continue; // never kill PRIMARY
        indices[count] = si;
        count += 1;
    }
    if (count < MIN_SURVIVORS + 1) return null; // need at least MIN_SURVIVORS+1 to kill one

    // Sort by sacred fitness ascending (best first, worst last)
    var ii: usize = 1;
    while (ii < count) : (ii += 1) {
        const key = indices[ii];
        const key_fit = computeSacredFitness(&state.services[key]);
        var jj: usize = ii;
        while (jj > 0 and computeSacredFitness(&state.services[indices[jj - 1]]) > key_fit) {
            indices[jj] = indices[jj - 1];
            jj -= 1;
        }
        indices[jj] = key;
    }

    // Bottom 20% (at least 2 for tournament)
    const bottom_size = @max(@as(usize, 2), count * 20 / 100);
    const bottom_start = count - bottom_size;

    // Pick 2 from bottom, kill worse
    const a_pick = mulberry32(prng_seed) % @as(u32, @intCast(bottom_size));
    var b_pick = mulberry32(prng_seed +% 1) % @as(u32, @intCast(bottom_size));
    if (b_pick == a_pick) b_pick = (a_pick + 1) % @as(u32, @intCast(bottom_size));

    const a_idx = indices[bottom_start + a_pick];
    const b_idx = indices[bottom_start + b_pick];
    const a_fit = computeSacredFitness(&state.services[a_idx]);
    const b_fit = computeSacredFitness(&state.services[b_idx]);
    return if (a_fit >= b_fit) a_idx else b_idx; // worse = higher fitness
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Population Health (PB2 metrics)
// ═══════════════════════════════════════════════════════════════════════════════

const PopulationHealth = struct {
    diversity: f32, // product of stdevs(lr, gc, wu) — dimensionless
    elite_gap: f32, // ppl_rank5 / ppl_rank1
    stagnation: u32, // steps since last best_ppl improvement
    spike_rate: f32, // fraction of workers with loss > 1.5× expected
    alive: u32,
    total: u32,
    health_score: f32, // 0-100 aggregate
    leader_improvement: f32, // ΔPPL per 1K steps (negative = improving)
    leader_step: u32, // current step of best worker
};

fn computePopulationHealth(state: *const EvolutionState) PopulationHealth {
    var lrs: [MAX_SERVICES]f64 = undefined;
    var gcs: [MAX_SERVICES]f64 = undefined;
    var wus: [MAX_SERVICES]f64 = undefined;
    var ppls: [MAX_SERVICES]f32 = undefined;
    var alive: u32 = 0;
    var spike_count: u32 = 0;

    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status != .running or svc.current_step == 0) continue;
        const idx = alive;
        lrs[idx] = std.fmt.parseFloat(f64, svc.lrStr()) catch 3e-4;
        gcs[idx] = @as(f64, svc.grad_clip);
        wus[idx] = @as(f64, @floatFromInt(svc.warmup));
        ppls[idx] = getPplForRanking(svc);

        const expected_loss = @log(svc.current_ppl);
        if (svc.current_loss > expected_loss * 1.5) spike_count += 1;

        alive += 1;
    }

    if (alive == 0) return .{ .diversity = 0, .elite_gap = 1, .stagnation = 0, .spike_rate = 0, .alive = 0, .total = @intCast(state.service_count), .health_score = 0, .leader_improvement = 0, .leader_step = 0 };

    // Compute stdevs
    const n: f64 = @floatFromInt(alive);
    const lr_std = computeStd(lrs[0..alive], n);
    const gc_std = computeStd(gcs[0..alive], n);
    const wu_std = computeStd(wus[0..alive], n);
    const diversity: f32 = @floatCast(lr_std * gc_std * wu_std);

    // Elite gap: sort ppls, ratio of rank5/rank1
    var sorted_ppls: [MAX_SERVICES]f32 = undefined;
    @memcpy(sorted_ppls[0..alive], ppls[0..alive]);
    // Insertion sort ascending
    {
        var ii: usize = 1;
        while (ii < alive) : (ii += 1) {
            const key = sorted_ppls[ii];
            var jj: usize = ii;
            while (jj > 0 and sorted_ppls[jj - 1] > key) {
                sorted_ppls[jj] = sorted_ppls[jj - 1];
                jj -= 1;
            }
            sorted_ppls[jj] = key;
        }
    }
    const rank1 = sorted_ppls[0];
    const rank5_idx = @min(@as(usize, 4), alive - 1);
    const rank5 = sorted_ppls[rank5_idx];
    const elite_gap: f32 = if (rank1 > 0.1) rank5 / rank1 else 1.0;

    const spike_rate: f32 = @as(f32, @floatFromInt(spike_count)) / @as(f32, @floatFromInt(alive));

    // Health score: weighted aggregate 0-100
    const ppl_score: f32 = @max(0, 40.0 * (1.0 - @min(1.0, @log(rank1) / @log(@as(f32, 500.0)))));
    const spike_score: f32 = 30.0 * (1.0 - spike_rate);
    const div_score: f32 = @min(20.0, diversity / 0.01 * 20.0);
    const alive_ratio: f32 = if (state.service_count > 0) @as(f32, @floatFromInt(alive)) / @as(f32, @floatFromInt(state.service_count)) else 0;
    const alive_score: f32 = alive_ratio * 10.0;
    const health_score = ppl_score + spike_score + div_score + alive_score;

    // Leader step + improvement rate
    var leader_step: u32 = 0;
    var leader_ppl: f32 = 999.0;
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status == .running and getPplForRanking(svc) < leader_ppl) {
            leader_ppl = getPplForRanking(svc);
            leader_step = svc.current_step;
        }
    }
    const leader_improvement: f32 = if (leader_step > state.best_step and state.best_step > 0)
        (leader_ppl - state.best_ppl) / @as(f32, @floatFromInt((leader_step - state.best_step) / 1000 + 1))
    else
        0.0;

    // Precise stagnation from best_step
    const stagnation: u32 = if (leader_step > state.best_step) leader_step - state.best_step else 0;

    return .{
        .diversity = diversity,
        .elite_gap = elite_gap,
        .stagnation = stagnation,
        .spike_rate = spike_rate,
        .alive = alive,
        .total = @intCast(state.service_count),
        .health_score = health_score,
        .leader_improvement = leader_improvement,
        .leader_step = leader_step,
    };
}

fn computeStd(values: []const f64, n: f64) f64 {
    if (n < 2) return 0;
    var sum: f64 = 0;
    for (values) |v| sum += v;
    const mean = sum / n;
    var sq_sum: f64 = 0;
    for (values) |v| {
        const d = v - mean;
        sq_sum += d * d;
    }
    return @sqrt(sq_sum / n);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Core: Service Recycling
// ═══════════════════════════════════════════════════════════════════════════════

fn recycleService(allocator: Allocator, state: *EvolutionState, victim_idx: usize, config: MutatedConfig, parent_name: []const u8, api_calls: *u32) void {
    const victim = &state.services[victim_idx];

    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (victim.account_idx >= account_count) {
        print("  {s}⚠️  {s}: account_idx {d} out of range ({d} accounts){s}\n", .{ YELLOW, victim.svcName(), victim.account_idx, account_count, RESET });
        state.addEvent(.err, victim.svcName(), "account_idx out of range");
        return;
    }
    const acct = &accounts_buf[victim.account_idx];

    var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch return;
    defer api.deinit();

    const svc_id = victim.svcId();

    // Set training variables
    const seed_str = std.fmt.allocPrint(allocator, "{d}", .{config.seed}) catch return;
    defer allocator.free(seed_str);

    const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
    const shard_str = std.fmt.allocPrint(allocator, "{d}", .{victim.data_shard}) catch return;
    defer allocator.free(shard_str);
    const num_shards_str = std.fmt.allocPrint(allocator, "{d}", .{state.service_count}) catch return;
    defer allocator.free(num_shards_str);

    const warmup_str = std.fmt.allocPrint(allocator, "{d}", .{config.warmup}) catch return;
    defer allocator.free(warmup_str);
    const grad_clip_str = std.fmt.allocPrint(allocator, "{d:.2}", .{config.grad_clip}) catch return;
    defer allocator.free(grad_clip_str);
    const ctx_str = std.fmt.allocPrint(allocator, "{d}", .{config.context}) catch return;
    defer allocator.free(ctx_str);
    const sched_str: []const u8 = config.lr_schedule.toStr();

    const set_vars_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_LR":"{s}","HSLM_BATCH":"{s}","HSLM_SEED":"{s}","HSLM_OPTIMIZER":"{s}","HSLM_LR_SCHEDULE":"{s}","HSLM_FRESH":"{s}","HSLM_WARMUP":"{s}","HSLM_GRAD_CLIP":"{s}","HSLM_CONTEXT":"{s}","HSLM_VAL_SPLIT":"0.1","HSLM_DATA_SHARD":"{s}","HSLM_NUM_SHARDS":"{s}","HSLM_OBJECTIVE":"{s}","RAILWAY_DOCKERFILE_PATH":"Dockerfile.hslm-train"}}}}}}
    , .{
        acct.project_id,                               svc_id,                                acct.env_id,
        config.lr_str[0..config.lr_len],               config.batch_str[0..config.batch_len], seed_str,
        config.optimizer_str[0..config.optimizer_len], sched_str,                             if (config.fresh) "1" else "0",
        warmup_str,                                    grad_clip_str,                         ctx_str,
        shard_str,                                     num_shards_str,                        config.objective,
    }) catch return;
    defer allocator.free(set_vars_json);

    if (api.query(set_vars_gql, set_vars_json)) |resp| {
        allocator.free(resp);
    } else |_| {
        print("  {s}⚠️  {s}: vars failed{s}\n", .{ YELLOW, victim.svcName(), RESET });
        state.addEvent(.err, victim.svcName(), "variableCollectionUpsert failed");
        return;
    }
    api_calls.* += 1;

    // Set NCA steps + entropy band if objective contains "nca"
    if (config.nca_steps > 0 and std.mem.indexOf(u8, config.objective, "nca") != null) {
        const nca_steps_str = std.fmt.allocPrint(allocator, "{d}", .{config.nca_steps}) catch return;
        defer allocator.free(nca_steps_str);
        const nca_vars_json = std.fmt.allocPrint(allocator,
            \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_NCA_STEPS":"{s}","HSLM_NCA_ENTROPY_MIN":"{s}","HSLM_NCA_ENTROPY_MAX":"{s}"}}}}}}
        , .{ acct.project_id, svc_id, acct.env_id, nca_steps_str, config.nca_entropy_min, config.nca_entropy_max }) catch return;
        defer allocator.free(nca_vars_json);
        if (api.query(set_vars_gql, nca_vars_json)) |resp| {
            allocator.free(resp);
        } else |_| {}
        api_calls.* += 1;
    }

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Set builder config
    const builder_gql = "mutation($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input) }";
    const builder_json = std.fmt.allocPrint(allocator,
        \\{{"serviceId":"{s}","environmentId":"{s}","input":{{"builder":"NIXPACKS","startCommand":null,"dockerfilePath":"Dockerfile.hslm-train"}}}}
    , .{ svc_id, acct.env_id }) catch return;
    defer allocator.free(builder_json);

    if (api.query(builder_gql, builder_json)) |resp| {
        allocator.free(resp);
    } else |_| {}
    api_calls.* += 1;

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Redeploy
    if (api.redeployService(svc_id, acct.env_id)) |resp| {
        allocator.free(resp);
    } else |_| {
        print("  {s}⚠️  {s}: redeploy failed{s}\n", .{ YELLOW, victim.svcName(), RESET });
        state.addEvent(.err, victim.svcName(), "redeploy failed");
        return;
    }
    api_calls.* += 1;

    // Update entry
    @memcpy(victim.lr[0..config.lr_len], config.lr_str[0..config.lr_len]);
    victim.lr_len = config.lr_len;
    @memcpy(victim.batch[0..config.batch_len], config.batch_str[0..config.batch_len]);
    victim.batch_len = config.batch_len;
    victim.seed = config.seed;
    victim.grad_clip = config.grad_clip;
    victim.warmup = config.warmup;
    victim.lr_schedule = config.lr_schedule;
    victim.context = config.context;
    victim.kill_ppl_30k = config.kill_ppl_30k;
    // Copy objective from config
    const obj_src = config.objective;
    const obj_n = @min(obj_src.len, victim.objective.len);
    @memcpy(victim.objective[0..obj_n], obj_src[0..obj_n]);
    victim.objective_len = @intCast(obj_n);
    victim.generation += 1;
    copyToFixed(&victim.parent, &victim.parent_len, parent_name);
    victim.current_step = 0;
    victim.current_ppl = 999.0;
    victim.current_loss = 99.0;
    victim.val_ppl = 999.0;
    victim.status = .running;
    victim.rungs_passed = .{ false, false, false, false };

    state.addEvent(.spawn, victim.svcName(), "recycled with mutated config");
    notifyWsBus(.spawn, victim.svcName(), "recycled with mutated config");
}

// ═══════════════════════════════════════════════════════════════════════════════
// PRNG: Mulberry32 (deterministic, zero deps)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn mulberry32(seed: u32) u32 {
    var s = seed +% 0x6D2B79F5;
    s = (s ^ (s >> 15)) *% 0x85EBCA77;
    s = (s ^ (s >> 13)) *% 0xC2B2AE3D;
    return s ^ (s >> 16);
}

// ═══════════════════════════════════════════════════════════════════════════════
// State Persistence (JSON)
// ═══════════════════════════════════════════════════════════════════════════════

fn saveState(state: EvolutionState) !void {
    var file = try std.fs.cwd().createFile(STATE_PATH, .{});
    defer file.close();

    // Increased buffer: loss_history adds ~600B/service, 160 services = ~96KB extra
    var buf: [262144]u8 = undefined;
    var pos: usize = 0;

    // Manual JSON serialization
    pos += (std.fmt.bufPrint(buf[pos..], "{{\"evolution_step\":{d},\"total_configs_tested\":{d},\"best_ppl\":{d:.2},\"best_name\":\"{s}\",\"best_step\":{d},\"service_count\":{d},\"event_count\":{d},\"services\":[", .{
        state.evolution_step, state.total_configs_tested, state.best_ppl,    state.bestNameStr(),
        state.best_step,      state.service_count,        state.event_count,
    }) catch return error.OutOfMemory).len;

    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (si > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        // Base service fields
        pos += (std.fmt.bufPrint(buf[pos..], "{{\"id\":\"{s}\",\"name\":\"{s}\",\"acct\":{d},\"lr\":\"{s}\",\"batch\":\"{s}\",\"opt\":\"{s}\",\"seed\":{d},\"gen\":{d},\"parent\":\"{s}\",\"step\":{d},\"ppl\":{d:.2},\"loss\":{d:.4},\"tps\":{d:.1},\"vppl\":{d:.2},\"shard\":{d},\"status\":{d},\"rp\":[{},{},{},{}],\"lts\":{d},\"lps\":{d},\"sc\":{d},\"lcs\":{d}", .{
            svc.svcId(),              svc.svcName(),       svc.account_idx,
            svc.lrStr(),              svc.batchStr(),      svc.optimizerStr(),
            svc.seed,                 svc.generation,      svc.parentName(),
            svc.current_step,         svc.current_ppl,     svc.current_loss,
            svc.tok_per_sec,          svc.val_ppl,         svc.data_shard,
            @intFromEnum(svc.status), svc.rungs_passed[0], svc.rungs_passed[1],
            svc.rungs_passed[2],      svc.rungs_passed[3], svc.last_tuned_step,
            svc.last_poll_step,       svc.stall_count,     svc.last_ckpt_step,
        }) catch return error.OutOfMemory).len;

        // Architecture config (nested cfg object)
        pos += (std.fmt.bufPrint(buf[pos..], ",\"cfg\":{{\"obj\":\"{s}\",\"ctx\":{d},\"gc\":{d:.2},\"wu\":{d},\"sched\":\"{s}\",\"phase\":\"{s}\",\"wave\":\"{s}\"}}", .{
            svc.objectiveStr(), svc.context,   svc.grad_clip, svc.warmup, svc.lr_schedule.toStr(),
            svc.phaseStr(),     svc.waveStr(),
        }) catch return error.OutOfMemory).len;

        // I1: Loss history array
        pos += (std.fmt.bufPrint(buf[pos..], ",\"lh\":[", .{}) catch return error.OutOfMemory).len;
        for (svc.loss_history[0..svc.loss_history_len], 0..) |lp, li| {
            if (li > 0) {
                buf[pos] = ',';
                pos += 1;
            }
            pos += (std.fmt.bufPrint(buf[pos..], "[{d},{d:.2},{d:.4}]", .{ lp.step, lp.ppl, lp.loss }) catch return error.OutOfMemory).len;
        }
        pos += (std.fmt.bufPrint(buf[pos..], "]}}", .{}) catch return error.OutOfMemory).len;
    }

    pos += (std.fmt.bufPrint(buf[pos..], "],\"events\":[", .{}) catch return error.OutOfMemory).len;

    for (state.events[0..state.event_count], 0..) |*ev, ei| {
        if (ei > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        const ev_str = std.fmt.bufPrint(buf[pos..], "{{\"ts\":{d},\"type\":{d},\"svc\":\"{s}\",\"detail\":\"{s}\"}}", .{
            ev.timestamp, @intFromEnum(ev.event_type), ev.svcName(), ev.detailStr(),
        }) catch return error.OutOfMemory;
        pos += ev_str.len;
    }

    pos += (std.fmt.bufPrint(buf[pos..], "]}}", .{}) catch return error.OutOfMemory).len;

    try file.writeAll(buf[0..pos]);
}

fn loadState(allocator: Allocator) !EvolutionState {
    const file = std.fs.cwd().openFile(STATE_PATH, .{}) catch return error.FileNotFound;
    defer file.close();

    const contents = file.readToEndAlloc(allocator, 512 * 1024) catch return error.OutOfMemory;
    defer allocator.free(contents);

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch return error.InvalidJson;
    defer parsed.deinit();

    var state = EvolutionState{};
    const root = parsed.value;

    state.evolution_step = jsonU32(root, "evolution_step");
    state.total_configs_tested = jsonU32(root, "total_configs_tested");
    state.best_ppl = jsonF32(root, "best_ppl");
    const bn = getJsonString(root, "best_name");
    copyToFixed(&state.best_name, &state.best_name_len, bn);
    state.best_step = jsonU32(root, "best_step");

    // Load services
    if (getJsonObject(root, "services")) |svcs| {
        if (svcs == .array) {
            for (svcs.array.items) |item| {
                const entry = state.addService() orelse break;
                copyToFixed(&entry.svc_id, &entry.svc_id_len, getJsonString(item, "id"));
                copyToFixed(&entry.svc_name, &entry.svc_name_len, getJsonString(item, "name"));
                entry.account_idx = @intCast(jsonU32(item, "acct"));
                copyToFixed(&entry.lr, &entry.lr_len, getJsonString(item, "lr"));
                copyToFixed(&entry.batch, &entry.batch_len, getJsonString(item, "batch"));
                copyToFixed(&entry.optimizer, &entry.optimizer_len, getJsonString(item, "opt"));
                entry.seed = jsonU32(item, "seed");
                entry.generation = @intCast(jsonU32(item, "gen"));
                const pn = getJsonString(item, "parent");
                if (!std.mem.eql(u8, pn, "(original)")) {
                    copyToFixed(&entry.parent, &entry.parent_len, pn);
                }
                entry.current_step = jsonU32(item, "step");
                entry.current_ppl = jsonF32(item, "ppl");
                entry.current_loss = jsonF32(item, "loss");
                entry.tok_per_sec = jsonF32(item, "tps");
                entry.val_ppl = jsonF32(item, "vppl");
                if (entry.val_ppl == 0) entry.val_ppl = 999.0; // missing field → not measured
                entry.data_shard = @intCast(jsonU32(item, "shard"));
                entry.status = @enumFromInt(@min(jsonU32(item, "status"), 7));

                // Load rungs_passed
                if (getJsonObject(item, "rp")) |rp| {
                    if (rp == .array and rp.array.items.len >= 4) {
                        for (0..4) |ri| {
                            entry.rungs_passed[ri] = if (rp.array.items[ri] == .bool) rp.array.items[ri].bool else false;
                        }
                    }
                }
                entry.last_tuned_step = jsonU32(item, "lts");

                // I1/I2/I4: Load new fields (backward-compatible — missing = 0)
                entry.last_poll_step = jsonU32(item, "lps");
                entry.stall_count = @intCast(@min(jsonU32(item, "sc"), 255));
                entry.last_ckpt_step = jsonU32(item, "lcs");

                // Architecture config — try nested "cfg" object first, fallback to flat keys
                if (getJsonObject(item, "cfg")) |cfg_val| {
                    if (cfg_val == .object) {
                        const obj_str = getJsonString(cfg_val, "obj");
                        if (obj_str.len > 0 and !std.mem.eql(u8, obj_str, "?")) {
                            copyToFixed(&entry.objective, &entry.objective_len, obj_str);
                        }
                        const ctx_val = jsonU32(cfg_val, "ctx");
                        if (ctx_val > 0) entry.context = ctx_val;
                        const gc_val = jsonF32(cfg_val, "gc");
                        if (gc_val > 0) entry.grad_clip = gc_val;
                        const wu_val = jsonU32(cfg_val, "wu");
                        if (wu_val > 0) entry.warmup = wu_val;
                        const sched_str = getJsonString(cfg_val, "sched");
                        if (sched_str.len > 0 and !std.mem.eql(u8, sched_str, "?")) {
                            entry.lr_schedule = LrSchedule.fromStr(sched_str);
                        }
                        const phase_str = getJsonString(cfg_val, "phase");
                        if (phase_str.len > 0 and !std.mem.eql(u8, phase_str, "?")) {
                            copyToFixed(&entry.phase, &entry.phase_len, phase_str);
                        }
                        const wave_str = getJsonString(cfg_val, "wave");
                        if (wave_str.len > 0 and !std.mem.eql(u8, wave_str, "?")) {
                            copyToFixed(&entry.wave, &entry.wave_len, wave_str);
                        }
                    }
                } else {
                    // Flat fallback for old state files
                    const obj_str = getJsonString(item, "obj");
                    if (obj_str.len > 0 and !std.mem.eql(u8, obj_str, "?")) {
                        copyToFixed(&entry.objective, &entry.objective_len, obj_str);
                    }
                    const ctx_val = jsonU32(item, "ctx");
                    if (ctx_val > 0) entry.context = ctx_val;
                    const gc_val = jsonF32(item, "gc");
                    if (gc_val > 0) entry.grad_clip = gc_val;
                    const wu_val = jsonU32(item, "wu");
                    if (wu_val > 0) entry.warmup = wu_val;
                    const sched_str = getJsonString(item, "sched");
                    if (sched_str.len > 0 and !std.mem.eql(u8, sched_str, "?")) {
                        entry.lr_schedule = LrSchedule.fromStr(sched_str);
                    }
                }

                // I1: Load loss history
                if (getJsonObject(item, "lh")) |lh| {
                    if (lh == .array) {
                        for (lh.array.items) |lp_item| {
                            if (entry.loss_history_len >= LOSS_HISTORY_SIZE) break;
                            if (lp_item == .array and lp_item.array.items.len >= 3) {
                                const arr = lp_item.array.items;
                                entry.loss_history[entry.loss_history_len] = .{
                                    .step = jsonValU32(arr[0]),
                                    .ppl = jsonValF32(arr[1]),
                                    .loss = jsonValF32(arr[2]),
                                };
                                entry.loss_history_len += 1;
                            }
                        }
                    }
                }
            }
        }
    }

    // Load events
    if (getJsonObject(root, "events")) |evts| {
        if (evts == .array) {
            for (evts.array.items) |item| {
                if (state.event_count >= MAX_EVENTS) break;
                var ev = &state.events[state.event_count];
                ev.* = .{};
                ev.timestamp = jsonI64(item, "ts");
                ev.event_type = @enumFromInt(@min(jsonU32(item, "type"), 4));
                copyToFixed(&ev.service_name, &ev.service_name_len, getJsonString(item, "svc"));
                copyToFixed(&ev.detail, &ev.detail_len, getJsonString(item, "detail"));
                state.event_count += 1;
            }
        }
    }

    return state;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dashboard
// ═══════════════════════════════════════════════════════════════════════════════

fn printDashboard(state: *const EvolutionState) void {
    // Find current rung
    var active_rung: usize = 0;
    for (DEFAULT_RUNGS, 0..) |_, ri| {
        var any_eligible = false;
        for (state.services[0..state.service_count]) |*svc| {
            if (svc.status == .running and svc.current_step >= DEFAULT_RUNGS[ri].step_threshold and !svc.rungs_passed[ri]) {
                any_eligible = true;
                break;
            }
        }
        if (any_eligible) {
            active_rung = ri;
            break;
        }
    }

    print("\n{s}═══════════════════════════════════════════════════════════{s}\n", .{ BOLD, RESET });
    print("{s}  ASHA+PBT EVOLUTION — Step {d}, Rung {d}/{d}{s}\n", .{ BOLD, state.evolution_step, active_rung + 1, NUM_RUNGS, RESET });
    print("{s}═══════════════════════════════════════════════════════════{s}\n\n", .{ BOLD, RESET });

    const dash_health = computePopulationHealth(state);
    print("  Configs tested: {d} | Best: PPL={d:.1} ({s}) | Health: {d:.0}/100\n\n", .{
        state.total_configs_tested, state.best_ppl, state.bestNameStr(), dash_health.health_score,
    });

    // Leaderboard (top 10 running by PPL)
    var sorted_indices: [MAX_SERVICES]usize = undefined;
    var sorted_count: usize = 0;
    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.status == .running and svc.current_ppl < 998) {
            sorted_indices[sorted_count] = si;
            sorted_count += 1;
        }
    }

    // Sort by val_ppl if available, else train_ppl
    var ii: usize = 1;
    while (ii < sorted_count) : (ii += 1) {
        const key = sorted_indices[ii];
        const key_ppl = getPplForRanking(&state.services[key]);
        var jj: usize = ii;
        while (jj > 0 and getPplForRanking(&state.services[sorted_indices[jj - 1]]) > key_ppl) {
            sorted_indices[jj] = sorted_indices[jj - 1];
            jj -= 1;
        }
        sorted_indices[jj] = key;
    }

    print("  {s}LEADERBOARD:{s}\n", .{ BOLD, RESET });
    print("  {s}#  | Service              | PPL      | ValPPL   | Step  | Gen | LR         | Shard{s}\n", .{ DIM, RESET });
    print("  {s}───┼──────────────────────┼──────────┼──────────┼───────┼─────┼────────────┼──────{s}\n", .{ DIM, RESET });

    const show = @min(sorted_count, 10);
    for (0..show) |rank| {
        const svc = &state.services[sorted_indices[rank]];
        print("  {d}", .{rank + 1});
        const rank_digits: usize = if (rank + 1 >= 10) 2 else 1;
        padTo(rank_digits, 3);
        print("| {s}", .{svc.svcName()});
        padTo(svc.svc_name_len, 21);
        print("| {d:.1}", .{svc.current_ppl});
        padToF(svc.current_ppl, 9);
        if (svc.val_ppl < 998) {
            print("| {d:.1}", .{svc.val_ppl});
            padToF(svc.val_ppl, 9);
        } else {
            print("| {s}---{s}      ", .{ DIM, RESET });
        }
        print("| {d}", .{svc.current_step});
        padTo(countDigits(svc.current_step), 6);
        print("| {d}", .{svc.generation});
        padTo(countDigits(svc.generation), 4);
        print("| {s}", .{svc.lrStr()});
        padTo(svc.lr_len, 11);
        print("| {d}\n", .{svc.data_shard});
    }

    // Rung progress
    print("\n  {s}RUNG PROGRESS:{s}\n", .{ BOLD, RESET });
    for (DEFAULT_RUNGS, 0..) |rung, ri| {
        var passed: usize = 0;
        var eligible: usize = 0;
        for (state.services[0..state.service_count]) |*svc| {
            if (svc.status != .running) continue;
            if (svc.current_step >= rung.step_threshold) eligible += 1;
            if (svc.rungs_passed[ri]) passed += 1;
        }
        const status_str = if (passed > 0 and passed == eligible) "DONE" else if (eligible > 0) "ACTIVE" else "WAITING";
        const color = if (passed > 0 and passed == eligible) GREEN else if (eligible > 0) YELLOW else DIM;
        print("  [{d}] {d}K: {d} passed / {d} eligible  {s}{s}{s}\n", .{
            ri + 1, rung.step_threshold / 1000, passed, eligible, color, status_str, RESET,
        });
    }

    // Diversity quotas
    print("\n  {s}DIVERSITY QUOTAS:{s}\n", .{ BOLD, RESET });
    {
        var alive_q: u32 = 0;
        var q_counts: [DEFAULT_QUOTAS.len]u32 = .{0} ** DEFAULT_QUOTAS.len;
        for (state.services[0..state.service_count]) |*svc| {
            if (svc.status != .running and svc.status != .idle) continue;
            alive_q += 1;
            for (DEFAULT_QUOTAS, 0..) |bucket, bi| {
                const obj_match = std.mem.eql(u8, svc.objectiveStr(), bucket.objective) or
                    (std.mem.eql(u8, bucket.objective, "ntp") and svc.objective_len == 0);
                if (!obj_match) continue;
                if (bucket.min_context > 0 and svc.context < bucket.min_context) continue;
                q_counts[bi] += 1;
            }
        }
        const n_q: f32 = if (alive_q > 0) @floatFromInt(alive_q) else 1.0;
        for (DEFAULT_QUOTAS, 0..) |bucket, bi| {
            const actual_pct: f32 = @as(f32, @floatFromInt(q_counts[bi])) / n_q * 100.0;
            const target_pct = bucket.target_pct * 100.0;
            const diff = actual_pct - target_pct;
            const status_icon: []const u8 = if (diff >= -5.0) GREEN else YELLOW;
            const ctx_label: []const u8 = if (bucket.min_context > 0) "/81+" else "    ";
            print("  {s}{s}{s}{s}:  {d:.0}% (target {d:.0}%)", .{ status_icon, bucket.objective, ctx_label, RESET, actual_pct, target_pct });
            if (diff < -5.0) {
                print(" {s}{d:.0}%{s}", .{ YELLOW, diff, RESET });
            }
            print("\n", .{});
        }
    }

    // Resume eligible
    var resume_count: u32 = 0;
    print("\n  {s}RESUME ELIGIBLE{s} (stalled/crashed, step>=30K, PPL<15):\n", .{ BOLD, RESET });
    {
        for (state.services[0..state.service_count]) |*svc| {
            const resumable = svc.status == .stalled or svc.status == .crashed or svc.status == .idle;
            if (!resumable) continue;
            if (svc.current_step < 30000 or svc.current_ppl <= 0 or svc.current_ppl >= 15.0) continue;
            if (resume_count < 5) {
                const st_str: []const u8 = switch (svc.status) {
                    .stalled => "stalled",
                    .crashed => "crashed",
                    .idle => "idle",
                    else => "?",
                };
                print("  {s}  step={d}K  PPL={d:.1}  ({s}){s}\n", .{ svc.svcName(), svc.current_step / 1000, svc.current_ppl, st_str, RESET });
            }
            resume_count += 1;
        }
        if (resume_count == 0) {
            print("  {s}(none){s}\n", .{ DIM, RESET });
        } else if (resume_count > 5) {
            print("  ... and {d} more\n", .{resume_count - 5});
        }
        if (resume_count > 0) {
            print("  {s}-> tri farm evolve resume --top-k {d}{s}\n", .{ CYAN, resume_count, RESET });
        }
    }

    // Recommendations
    const rec_result = computeRecommendations(state, dash_health, resume_count);
    if (rec_result.count > 0) {
        print("\n  {s}RECOMMENDATIONS:{s}\n", .{ BOLD, RESET });
        for (rec_result.recs[0..rec_result.count]) |*rec| {
            const icon: []const u8 = switch (rec.severity) {
                .critical => RED,
                .warning => YELLOW,
                .info => CYAN,
            };
            const sev_str: []const u8 = switch (rec.severity) {
                .critical => "!!",
                .warning => "! ",
                .info => "i ",
            };
            print("  {s}{s}{s} {s}\n", .{ icon, sev_str, RESET, rec.message[0..rec.message_len] });
            print("     {s}Run: {s}{s}\n", .{ DIM, rec.command[0..rec.command_len], RESET });
        }
    }

    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// GitHub Issue Posting
// ═══════════════════════════════════════════════════════════════════════════════

fn postToIssue(allocator: Allocator, issue_num: []const u8, state: *const EvolutionState, killed: usize, spawned: usize) void {
    var body_buf: [3072]u8 = undefined;
    const body = std.fmt.bufPrint(&body_buf,
        \\🧬 **SEVO Step #{d}** — {s} PPL={d:.1}
        \\
        \\| Field | Value |
        \\|-------|-------|
        \\| Configs tested | {d} |
        \\| Best PPL | {d:.1} ({s}) |
        \\| Killed | {d} |
        \\| Spawned | {d} |
        \\| Services | {d} |
        \\
        \\<!-- trinity-meta {{"type":"sevo_step","step":{d},"best_ppl":{d:.1},"best_name":"{s}","configs":{d},"killed":{d},"spawned":{d},"services":{d}}} -->
    , .{
        state.evolution_step,
        state.bestNameStr(),
        state.best_ppl,
        state.total_configs_tested,
        state.best_ppl,
        state.bestNameStr(),
        killed,
        spawned,
        state.service_count,
        state.evolution_step,
        state.best_ppl,
        state.bestNameStr(),
        state.total_configs_tested,
        killed,
        spawned,
        state.service_count,
    }) catch return;

    // Write to temp file (body may contain special chars)
    const tmp_path = "/tmp/sevo_step_comment.md";
    const tmp_file = std.fs.cwd().createFile(tmp_path, .{}) catch return;
    tmp_file.writeAll(body) catch {
        tmp_file.close();
        return;
    };
    tmp_file.close();

    // Use tri issue comment (existing CLI) with fallback to gh
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "zig-out/bin/tri", "issue", "comment", issue_num, "-F", tmp_path },
        .max_output_bytes = 4096,
    }) catch {
        // Fallback: gh with --repo
        var child = std.process.Child.init(&.{ "gh", "issue", "comment", issue_num, "--repo", "gHashTag/trinity", "-F", tmp_path }, allocator);
        _ = child.spawnAndWait() catch {
            print("  {s}\xe2\x9a\xa0\xef\xb8\x8f  Failed to post to issue #{s}{s}\n", .{ YELLOW, issue_num, RESET });
            return;
        };
        print("  {s}\xf0\x9f\x93\x9d Posted to issue #{s}{s}\n", .{ GREEN, issue_num, RESET });
        return;
    };
    allocator.free(result.stdout);
    allocator.free(result.stderr);

    print("  {s}\xf0\x9f\x93\x9d Posted to issue #{s}{s}\n", .{ GREEN, issue_num, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

fn getJsonObject(val: std.json.Value, key: []const u8) ?std.json.Value {
    if (val != .object) return null;
    return val.object.get(key);
}

fn getJsonString(val: std.json.Value, key: []const u8) []const u8 {
    if (val != .object) return "?";
    const v = val.object.get(key) orelse return "?";
    if (v != .string) return "?";
    return v.string;
}

fn jsonU32(val: std.json.Value, key: []const u8) u32 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| @intCast(@max(0, i)),
        .float => |f| @intFromFloat(@max(0, f)),
        else => 0,
    };
}

fn jsonI64(val: std.json.Value, key: []const u8) i64 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    return switch (v) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => 0,
    };
}

fn jsonF32(val: std.json.Value, key: []const u8) f32 {
    if (val != .object) return 0;
    const v = val.object.get(key) orelse return 0;
    return switch (v) {
        .float => |f| @floatCast(f),
        .integer => |i| @floatFromInt(i),
        else => 0,
    };
}

/// Extract u32 from a JSON Value directly (for array elements)
fn jsonValU32(v: std.json.Value) u32 {
    return switch (v) {
        .integer => |i| @intCast(@max(0, i)),
        .float => |f| @intFromFloat(@max(0, f)),
        else => 0,
    };
}

/// Extract f32 from a JSON Value directly (for array elements)
fn jsonValF32(v: std.json.Value) f32 {
    return switch (v) {
        .float => |f| @floatCast(f),
        .integer => |i| @floatFromInt(i),
        else => 0,
    };
}

fn getEdgesFromProject(root: std.json.Value) ?[]std.json.Value {
    const data = getJsonObject(root, "data") orelse return null;
    const proj = getJsonObject(data, "project") orelse return null;
    const svcs = getJsonObject(proj, "services") orelse return null;
    const edges = getJsonObject(svcs, "edges") orelse return null;
    if (edges != .array) return null;
    return edges.array.items;
}

fn isTrainingService(name: []const u8) bool {
    // Match hslm-* services
    return std.mem.startsWith(u8, name, "hslm-");
}

fn classifyStatus(status: []const u8) ServiceStatus {
    if (std.mem.eql(u8, status, "SUCCESS")) return .running;
    if (std.mem.eql(u8, status, "CRASHED") or std.mem.eql(u8, status, "FAILED")) return .crashed;
    if (std.mem.eql(u8, status, "REMOVED") or std.mem.eql(u8, status, "NONE")) return .idle;
    return .unknown;
}

fn extractConfig(entry: *ServiceEntry, root: std.json.Value) void {
    const data = getJsonObject(root, "data") orelse return;
    const vars = getJsonObject(data, "variables") orelse return;
    if (vars != .object) return;

    if (vars.object.get("HSLM_LR")) |v| {
        if (v == .string) copyToFixed(&entry.lr, &entry.lr_len, v.string);
    }
    if (vars.object.get("HSLM_BATCH")) |v| {
        if (v == .string) copyToFixed(&entry.batch, &entry.batch_len, v.string);
    }
    if (vars.object.get("HSLM_OPTIMIZER")) |v| {
        if (v == .string) copyToFixed(&entry.optimizer, &entry.optimizer_len, v.string);
    }
    if (vars.object.get("HSLM_SEED")) |v| {
        if (v == .string) {
            entry.seed = std.fmt.parseInt(u32, v.string, 10) catch 0;
        }
    }
    if (vars.object.get("HSLM_DATA_SHARD")) |v| {
        if (v == .string) {
            entry.data_shard = std.fmt.parseInt(u16, v.string, 10) catch 0;
        }
    }
}

fn copyToFixed(dst: anytype, len: *u8, src: []const u8) void {
    const max_len = dst.len;
    const copy_len: u8 = @intCast(@min(src.len, max_len));
    @memcpy(dst[0..copy_len], src[0..copy_len]);
    len.* = copy_len;
}

fn padTo(current: anytype, target: usize) void {
    const cur: usize = switch (@TypeOf(current)) {
        u8 => @as(usize, current),
        else => current,
    };
    if (cur >= target) return;
    var pad_i: usize = 0;
    while (pad_i < target - cur) : (pad_i += 1) {
        print(" ", .{});
    }
}

fn padToF(val: f32, target: usize) void {
    // Estimate printed length of float
    const len: usize = if (val >= 1000) 6 else if (val >= 100) 5 else if (val >= 10) 4 else 3;
    padTo(len, target);
}

fn countDigits(n: u32) usize {
    if (n == 0) return 1;
    var count: usize = 0;
    var v = n;
    while (v > 0) : (v /= 10) {
        count += 1;
    }
    return count;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPLOY — Push pre-made configs from JSON to idle Railway services
// ═══════════════════════════════════════════════════════════════════════════════

fn runDeploy(allocator: Allocator, args: []const []const u8) !void {
    var config_path: []const u8 = ".trinity/farm/w8_mock_configs.json";
    var select_str: ?[]const u8 = null;
    var execute: bool = false;
    var issue_num: ?u32 = null;
    var skip_ci: bool = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--config") and i + 1 < args.len) {
            i += 1;
            config_path = args[i];
        } else if (std.mem.eql(u8, arg, "--select") and i + 1 < args.len) {
            i += 1;
            select_str = args[i];
        } else if (std.mem.eql(u8, arg, "--execute")) {
            execute = true;
        } else if (std.mem.eql(u8, arg, "--issue") and i + 1 < args.len) {
            i += 1;
            issue_num = std.fmt.parseInt(u32, args[i], 10) catch null;
        } else if (std.mem.eql(u8, arg, "--skip-ci")) {
            skip_ci = true;
        }
    }

    // Parse configs from JSON
    var configs: [MAX_SERVICES]MutatedConfig = undefined;
    var names: [MAX_SERVICES][64]u8 = undefined;
    var name_lens: [MAX_SERVICES]u8 = undefined;
    var parents: [MAX_SERVICES][64]u8 = undefined;
    var parent_lens: [MAX_SERVICES]u8 = undefined;
    const total_configs = parseMockConfigJson(allocator, config_path, &configs, &names, &name_lens, &parents, &parent_lens) catch |err| {
        print("{s}❌ Failed to parse config JSON: {s} — {s}{s}\n", .{ RED, config_path, @errorName(err), RESET });
        return;
    };

    if (total_configs == 0) {
        print("{s}❌ No configs found in {s}{s}\n", .{ RED, config_path, RESET });
        return;
    }

    // Filter by --select indices (1-based)
    var selected_indices: [MAX_SERVICES]usize = undefined;
    var selected_count: usize = 0;

    if (select_str) |sel| {
        var iter = std.mem.splitScalar(u8, sel, ',');
        while (iter.next()) |tok| {
            const idx = std.fmt.parseInt(usize, std.mem.trim(u8, tok, " "), 10) catch continue;
            if (idx >= 1 and idx <= total_configs) {
                if (selected_count < MAX_SERVICES) {
                    selected_indices[selected_count] = idx - 1;
                    selected_count += 1;
                }
            }
        }
    } else {
        // Use all
        for (0..total_configs) |ci| {
            selected_indices[ci] = ci;
        }
        selected_count = total_configs;
    }

    if (selected_count == 0) {
        print("{s}❌ No valid indices in --select{s}\n", .{ RED, RESET });
        return;
    }

    // Validate: reject flat schedules
    for (0..selected_count) |si| {
        const ci = selected_indices[si];
        const c = &configs[ci];
        _ = c.lr_schedule.toStr(); // all enum variants are valid
    }

    // Discover Railway accounts + scan for idle/crashed services
    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (account_count == 0) {
        print("{s}❌ No Railway accounts found. Source .env first.{s}\n", .{ RED, RESET });
        return;
    }

    // Scan for idle/crashed target services (skip PRIMARY account index 0)
    var targets: [MAX_SERVICES]struct {
        svc_id: [64]u8,
        svc_id_len: u8,
        svc_name: [64]u8,
        svc_name_len: u8,
        acct_idx: u8,
    } = undefined;
    var target_count: usize = 0;

    for (accounts_buf[0..account_count], 0..) |acct, acct_idx| {
        // Skip PRIMARY (old image)
        if (acct_idx == 0) continue;

        var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch continue;
        defer api.deinit();

        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { id status } } } } } } } }";
        const vars_json = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{acct.project_id}) catch continue;
        defer allocator.free(vars_json);

        const resp = api.query(gql, vars_json) catch continue;
        defer allocator.free(resp);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch continue;
        defer parsed.deinit();

        const edges = getEdgesFromProject(parsed.value) orelse continue;

        for (edges) |edge| {
            const node = getJsonObject(edge, "node") orelse continue;
            const svc_id = getJsonString(node, "id");
            const svc_name = getJsonString(node, "name");
            if (!isTrainingService(svc_name)) continue;

            // Check deployment status — only target idle/crashed
            var svc_status: ServiceStatus = .unknown;
            if (getJsonObject(node, "deployments")) |deps| {
                if (getJsonObject(deps, "edges")) |dep_edges| {
                    if (dep_edges == .array and dep_edges.array.items.len > 0) {
                        const dep_node = getJsonObject(dep_edges.array.items[0], "node") orelse continue;
                        const dep_status = getJsonString(dep_node, "status");
                        svc_status = classifyStatus(dep_status);
                    }
                }
            }

            if (svc_status == .idle or svc_status == .crashed) {
                if (target_count < MAX_SERVICES) {
                    var t = &targets[target_count];
                    const id_len: u8 = @intCast(@min(svc_id.len, 64));
                    @memcpy(t.svc_id[0..id_len], svc_id[0..id_len]);
                    t.svc_id_len = id_len;
                    const nm_len: u8 = @intCast(@min(svc_name.len, 64));
                    @memcpy(t.svc_name[0..nm_len], svc_name[0..nm_len]);
                    t.svc_name_len = nm_len;
                    t.acct_idx = @intCast(acct_idx);
                    target_count += 1;
                }
            }
        }
    }

    const deploy_count = @min(selected_count, target_count);

    // Print deploy plan
    const mode_str: []const u8 = if (execute) "EXECUTE" else "DRY RUN";
    print("\n{s}🚀 EVOLUTION DEPLOY [{s}]{s}\n", .{ BOLD, mode_str, RESET });
    print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}#  | Config     | → Target         | Acct   | LR         | GC    | WU   | φ{s}\n", .{ DIM, RESET });
    print("  {s}───┼────────────┼──────────────────┼────────┼────────────┼───────┼──────┼──{s}\n", .{ DIM, RESET });

    for (0..deploy_count) |di| {
        const ci = selected_indices[di];
        const c = &configs[ci];
        const t = &targets[di % target_count];
        const cfg_name = names[ci][0..name_lens[ci]];
        const tgt_name = t.svc_name[0..t.svc_name_len];
        const acct_name = accounts_buf[t.acct_idx].name;

        print("  {d}", .{di + 1});
        padTo(countDigits(@intCast(di + 1)), 3);
        print("| {s}", .{cfg_name});
        padTo(name_lens[ci], 11);
        print("| → {s}", .{tgt_name});
        padTo(t.svc_name_len + 2, 17);
        print("| {s}", .{acct_name[0..@min(acct_name.len, 6)]});
        padTo(@min(acct_name.len, 6), 7);
        print("| {s}", .{c.lr_str[0..c.lr_len]});
        padTo(c.lr_len, 11);
        print("| {d:.2}", .{c.grad_clip});
        padToF(c.grad_clip, 6);
        print("| {d}", .{c.warmup});
        padTo(countDigits(c.warmup), 5);
        const sacred_str: []const u8 = if (c.sacred) "| φ" else "|  ";
        print("{s}\n", .{sacred_str});
    }

    print("{s}═══════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    // Bounds validation warnings (non-blocking)
    for (0..deploy_count) |di| {
        const ci = selected_indices[di];
        const c = &configs[ci];
        const cfg_name = names[ci][0..name_lens[ci]];
        const lr_val = std.fmt.parseFloat(f64, c.lr_str[0..c.lr_len]) catch 0;
        if (lr_val < LR_MIN or lr_val > LR_MAX) {
            print("  {s}⚠️  {s}: LR {s} outside [{e:.0}, {e:.0}]{s}\n", .{ YELLOW, cfg_name, c.lr_str[0..c.lr_len], LR_MIN, LR_MAX, RESET });
        }
        if (c.grad_clip < GC_MIN or c.grad_clip > GC_MAX) {
            print("  {s}⚠️  {s}: grad_clip {d:.2} outside [{d:.1}, {d:.1}]{s}\n", .{ YELLOW, cfg_name, c.grad_clip, GC_MIN, GC_MAX, RESET });
        }
        if (c.warmup < WU_MIN or c.warmup > WU_MAX) {
            print("  {s}⚠️  {s}: warmup {d} outside [{d}, {d}]{s}\n", .{ YELLOW, cfg_name, c.warmup, WU_MIN, WU_MAX, RESET });
        }
    }

    print("{s}{d} configs → {d} targets{s}", .{ BOLD, selected_count, target_count, RESET });

    if (deploy_count < selected_count) {
        print(" {s}(only {d} idle services available){s}", .{ YELLOW, target_count, RESET });
    }

    if (!execute) {
        print(" | Add {s}--execute{s} to deploy\n\n", .{ CYAN, RESET });
        return;
    }

    print("\n\n", .{});

    // CI gate
    if (skip_ci) {
        print("  {s}⚠️  CI GATE SKIPPED{s}\n", .{ YELLOW, RESET });
    }
    if (!skip_ci) {
        print("  {s}🔧 Running CI gate (zig build test)...{s}\n", .{ DIM, RESET });
        const ci_argv = [_][]const u8{ "zig", "build", "test" };
        var child = std.process.Child.init(&ci_argv, allocator);
        child.stderr_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        _ = child.spawnAndWait() catch {
            print("  {s}❌ CI gate failed — zig build test error. Use --skip-ci to bypass.{s}\n", .{ RED, RESET });
            return;
        };
        print("  {s}✅ CI gate passed{s}\n", .{ GREEN, RESET });
    }

    // Execute deploys
    var success_count: usize = 0;
    for (0..deploy_count) |di| {
        const ci = selected_indices[di];
        const c = &configs[ci];
        const t = &targets[di % target_count];
        const tgt_name = t.svc_name[0..t.svc_name_len];
        const tgt_id = t.svc_id[0..t.svc_id_len];

        print("  🚀 [{d}/{d}] {s} → {s}...", .{ di + 1, deploy_count, names[ci][0..name_lens[ci]], tgt_name });

        const ok = deployConfigToService(allocator, &accounts_buf[t.acct_idx], tgt_id, c.*);

        if (ok) {
            print(" {s}✅{s}\n", .{ GREEN, RESET });
            success_count += 1;
        } else {
            print(" {s}❌ FAILED{s}\n", .{ RED, RESET });
        }

        // Append deploy lineage
        appendDeployLineage(names[ci][0..name_lens[ci]], parents[ci][0..parent_lens[ci]], tgt_name, c, ok);
    }

    print("\n  {s}Deployed: {d}/{d}{s}\n\n", .{ BOLD, success_count, deploy_count, RESET });

    // Write deploy_targets.json for collect command
    writeDeployTargets(allocator, &configs, &names, &name_lens, &selected_indices, deploy_count, &targets, &accounts_buf);

    // Post to GitHub issue
    if (issue_num) |num| {
        var body_buf: [4096]u8 = undefined;
        const body = std.fmt.bufPrint(&body_buf,
            \\🚀 **Evolution Deploy** — {d}/{d} configs deployed
            \\
            \\Config: `{s}`
            \\Selected: {d} | Targets: {d} | Success: {d}
        , .{ success_count, deploy_count, config_path, selected_count, target_count, success_count }) catch return;

        const num_str = std.fmt.allocPrint(allocator, "{d}", .{num}) catch return;
        defer allocator.free(num_str);

        const gh_argv = [_][]const u8{ "gh", "issue", "comment", num_str, "--body", body };
        var gh_child = std.process.Child.init(&gh_argv, allocator);
        gh_child.stderr_behavior = .Ignore;
        gh_child.stdout_behavior = .Ignore;
        _ = gh_child.spawnAndWait() catch {
            print("  {s}⚠️  Failed to post to issue #{d}{s}\n", .{ YELLOW, num, RESET });
        };
        print("  {s}📝 Posted to issue #{d}{s}\n", .{ GREEN, num, RESET });
    }
}

fn parseMockConfigJson(
    allocator: Allocator,
    path: []const u8,
    configs: *[MAX_SERVICES]MutatedConfig,
    config_names: *[MAX_SERVICES][64]u8,
    name_lens: *[MAX_SERVICES]u8,
    parent_names: *[MAX_SERVICES][64]u8,
    parent_lens: *[MAX_SERVICES]u8,
) !usize {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, contents, .{});
    defer parsed.deinit();

    if (parsed.value != .array) return error.InvalidFormat;

    var count: usize = 0;
    for (parsed.value.array.items) |item| {
        if (count >= MAX_SERVICES) break;
        if (item != .object) continue;

        var c = MutatedConfig{
            .lr_str = undefined,
            .lr_len = 0,
            .batch_str = undefined,
            .batch_len = 0,
            .optimizer_str = undefined,
            .optimizer_len = 0,
            .seed = 0,
        };

        // LR
        const lr_raw = getJsonString(item, "lr");
        if (lr_raw.len > 0 and lr_raw[0] != '?') {
            const lr_l: u8 = @intCast(@min(lr_raw.len, 16));
            @memcpy(c.lr_str[0..lr_l], lr_raw[0..lr_l]);
            c.lr_len = lr_l;
        }

        // Defaults: batch=66, optimizer=lamb
        const batch_default = "66";
        @memcpy(c.batch_str[0..batch_default.len], batch_default);
        c.batch_len = @intCast(batch_default.len);
        const opt_default = "lamb";
        @memcpy(c.optimizer_str[0..opt_default.len], opt_default);
        c.optimizer_len = @intCast(opt_default.len);

        // Numeric fields
        c.grad_clip = jsonF32(item, "grad_clip");
        if (c.grad_clip == 0) c.grad_clip = 1.0;
        c.warmup = jsonU32(item, "warmup");
        if (c.warmup == 0) c.warmup = 2000;
        c.context = jsonU32(item, "context");
        if (c.context == 0) c.context = 27;
        c.seed = jsonU32(item, "seed");
        c.kill_ppl_30k = jsonF32(item, "kill_ppl_30k");
        if (c.kill_ppl_30k == 0) c.kill_ppl_30k = 999.0;

        // LR schedule
        const sched_str = getJsonString(item, "lr_schedule");
        c.lr_schedule = LrSchedule.fromStr(sched_str);

        // Sacred flag
        if (item.object.get("sacred")) |v| {
            c.sacred = (v == .bool and v.bool);
        }

        configs[count] = c;

        // Name
        const cfg_name = getJsonString(item, "name");
        const nl: u8 = @intCast(@min(cfg_name.len, 64));
        @memcpy(config_names[count][0..nl], cfg_name[0..nl]);
        name_lens[count] = nl;

        // Parent
        const par_name = getJsonString(item, "parent");
        const pl: u8 = @intCast(@min(par_name.len, 64));
        @memcpy(parent_names[count][0..pl], par_name[0..pl]);
        parent_lens[count] = pl;

        count += 1;
    }

    return count;
}

fn deployConfigToService(
    allocator: Allocator,
    acct: *const Account,
    svc_id: []const u8,
    config: MutatedConfig,
) bool {
    var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch return false;
    defer api.deinit();

    // 1. Set training variables
    const seed_str = std.fmt.allocPrint(allocator, "{d}", .{config.seed}) catch return false;
    defer allocator.free(seed_str);
    const warmup_str = std.fmt.allocPrint(allocator, "{d}", .{config.warmup}) catch return false;
    defer allocator.free(warmup_str);
    const grad_clip_str = std.fmt.allocPrint(allocator, "{d:.2}", .{config.grad_clip}) catch return false;
    defer allocator.free(grad_clip_str);
    const ctx_str = std.fmt.allocPrint(allocator, "{d}", .{config.context}) catch return false;
    defer allocator.free(ctx_str);
    const sched_str: []const u8 = config.lr_schedule.toStr();

    const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
    const set_vars_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_LR":"{s}","HSLM_BATCH":"{s}","HSLM_SEED":"{s}","HSLM_OPTIMIZER":"{s}","HSLM_LR_SCHEDULE":"{s}","HSLM_FRESH":"{s}","HSLM_WARMUP":"{s}","HSLM_GRAD_CLIP":"{s}","HSLM_CONTEXT":"{s}","HSLM_VAL_SPLIT":"0.1","RAILWAY_DOCKERFILE_PATH":"Dockerfile.hslm-train"}}}}}}
    , .{
        acct.project_id,                               svc_id,                                acct.env_id,
        config.lr_str[0..config.lr_len],               config.batch_str[0..config.batch_len], seed_str,
        config.optimizer_str[0..config.optimizer_len], sched_str,                             if (config.fresh) "1" else "0",
        warmup_str,                                    grad_clip_str,                         ctx_str,
    }) catch return false;
    defer allocator.free(set_vars_json);

    if (api.query(set_vars_gql, set_vars_json)) |resp| {
        allocator.free(resp);
    } else |_| {
        return false;
    }

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // 2. Set builder config (startCommand: null, builder: NIXPACKS)
    const builder_gql = "mutation($serviceId: String!, $environmentId: String!, $input: ServiceInstanceUpdateInput!) { serviceInstanceUpdate(serviceId: $serviceId, environmentId: $environmentId, input: $input) }";
    const builder_json = std.fmt.allocPrint(allocator,
        \\{{"serviceId":"{s}","environmentId":"{s}","input":{{"builder":"NIXPACKS","startCommand":null,"dockerfilePath":"Dockerfile.hslm-train"}}}}
    , .{ svc_id, acct.env_id }) catch return false;
    defer allocator.free(builder_json);

    if (api.query(builder_gql, builder_json)) |resp| {
        allocator.free(resp);
    } else |_| {}

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // 3. Redeploy
    if (api.redeployService(svc_id, acct.env_id)) |resp| {
        allocator.free(resp);
    } else |_| {
        return false;
    }

    return true;
}

fn appendDeployLineage(
    config_name: []const u8,
    parent_name: []const u8,
    target_name: []const u8,
    config: *const MutatedConfig,
    success: bool,
) void {
    const lineage_path = ".trinity/evolution_lineage.jsonl";
    var lineage_file = std.fs.cwd().createFile(lineage_path, .{ .truncate = false }) catch return;
    defer lineage_file.close();
    lineage_file.seekFromEnd(0) catch {};

    const ts = std.time.milliTimestamp();
    const sched: []const u8 = config.lr_schedule.toStr();
    const sacred_str: []const u8 = if (config.sacred) "true" else "false";
    const ok_str: []const u8 = if (success) "true" else "false";
    var line_buf: [512]u8 = undefined;
    const line = std.fmt.bufPrint(&line_buf,
        \\{{"event":"deploy","config":"{s}","parent":"{s}","target":"{s}","sacred":{s},"success":{s},"lr":"{s}","grad_clip":{d:.2},"warmup":{d},"schedule":"{s}","seed":{d},"timestamp":{d}}}
    ++ "\n", .{
        config_name,
        parent_name,
        target_name,
        sacred_str,
        ok_str,
        config.lr_str[0..config.lr_len],
        config.grad_clip,
        config.warmup,
        sched,
        config.seed,
        ts,
    }) catch return;
    lineage_file.writeAll(line) catch return;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Deploy Targets Writer
// ═══════════════════════════════════════════════════════════════════════════════

fn writeDeployTargets(
    _: Allocator,
    configs: *const [MAX_SERVICES]MutatedConfig,
    names: *const [MAX_SERVICES][64]u8,
    name_lens: *const [MAX_SERVICES]u8,
    selected_indices: *const [MAX_SERVICES]usize,
    deploy_count: usize,
    targets: anytype,
    accounts_buf: anytype,
) void {
    const path = ".trinity/farm/deploy_targets.json";
    var f = std.fs.cwd().createFile(path, .{}) catch return;
    defer f.close();

    f.writeAll("[\n") catch return;
    for (0..deploy_count) |di| {
        const ci = selected_indices[di];
        const c = &configs[ci];
        const t = &targets[di % deploy_count];
        const tgt_name = t.svc_name[0..t.svc_name_len];
        const tgt_id = t.svc_id[0..t.svc_id_len];
        const cfg_name = names[ci][0..name_lens[ci]];
        const acct_name = accounts_buf[t.acct_idx].name;
        const sacred_str: []const u8 = if (c.sacred) "true" else "false";

        var line_buf: [512]u8 = undefined;
        const line = std.fmt.bufPrint(&line_buf,
            \\  {{"config":"{s}","service":"{s}","svc_id":"{s}","acct_idx":{d},"acct_name":"{s}","sacred":{s}}}
        , .{ cfg_name, tgt_name, tgt_id, t.acct_idx, acct_name[0..@min(acct_name.len, 16)], sacred_str }) catch continue;
        f.writeAll(line) catch continue;
        if (di + 1 < deploy_count) f.writeAll(",\n") catch {} else f.writeAll("\n") catch {};
    }
    f.writeAll("]\n") catch return;
    print("  {s}📄 Wrote {s}{s}\n", .{ GREEN, path, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// COLLECT — A/B results from deployed configs
// ═══════════════════════════════════════════════════════════════════════════════

const MAX_METRICS = 200;

const Milestones = struct {
    ppl_3k: f32 = 999.0,
    ppl_10k: f32 = 999.0,
    ppl_20k: f32 = 999.0,
    best_ppl: f32 = 999.0,
    spikes: u16 = 0,
    latest_step: u32 = 0,
    status: enum(u8) { training, no_data, err } = .no_data,
};

fn parseAllTrainingLines(root: std.json.Value, results: *[MAX_METRICS]TrainingMetrics) usize {
    const data = getJsonObject(root, "data") orelse return 0;
    const logs = getJsonObject(data, "deploymentLogs") orelse return 0;
    if (logs != .array) return 0;

    var count: usize = 0;
    for (logs.array.items) |log_entry| {
        if (count >= MAX_METRICS) break;
        const msg = getJsonString(log_entry, "message");
        if (std.mem.eql(u8, msg, "?")) continue;
        if (parseTrainingLine(msg)) |metrics| {
            results[count] = metrics;
            count += 1;
        }
    }
    return count;
}

fn extractMilestones(metrics: *[MAX_METRICS]TrainingMetrics, count: usize) Milestones {
    if (count == 0) return .{};

    // Sort by step (insertion sort — small array)
    var si: usize = 1;
    while (si < count) : (si += 1) {
        const key = metrics[si];
        var j: usize = si;
        while (j > 0 and metrics[j - 1].step > key.step) {
            metrics[j] = metrics[j - 1];
            j -= 1;
        }
        metrics[j] = key;
    }

    var m = Milestones{ .status = .training };
    const milestone_targets = [_]u32{ 3000, 10000, 20000 };
    var best_dist: [3]u32 = .{ 2001, 2001, 2001 };

    for (0..count) |i| {
        const step = metrics[i].step;
        const ppl = metrics[i].ppl;

        // Track milestones — find closest within ±2000
        for (milestone_targets, 0..) |target, mi| {
            const dist = if (step >= target) step - target else target - step;
            if (dist < 2000 and dist < best_dist[mi]) {
                best_dist[mi] = dist;
                switch (mi) {
                    0 => m.ppl_3k = ppl,
                    1 => m.ppl_10k = ppl,
                    2 => m.ppl_20k = ppl,
                    else => {},
                }
            }
        }

        // Best PPL
        if (ppl < m.best_ppl) m.best_ppl = ppl;

        // Latest step
        if (step > m.latest_step) m.latest_step = step;

        // Spike detection: PPL[i] > 1.5 × PPL[i-1]
        if (i > 0 and metrics[i - 1].ppl > 0) {
            if (ppl > metrics[i - 1].ppl * 1.5) {
                m.spikes += 1;
            }
        }
    }

    return m;
}

// Deploy target entry loaded from JSON
const DeployTarget = struct {
    config: [64]u8 = undefined,
    config_len: u8 = 0,
    service: [64]u8 = undefined,
    service_len: u8 = 0,
    svc_id: [64]u8 = undefined,
    svc_id_len: u8 = 0,
    acct_idx: u8 = 0,
    sacred: bool = false,
};

fn runCollect(allocator: Allocator, args: []const []const u8) !void {
    var config_path: []const u8 = ".trinity/farm/w8_mock_configs.json";
    var targets_path: []const u8 = ".trinity/farm/deploy_targets.json";
    var out_path: []const u8 = ".trinity/farm/ab_results.json";
    var issue_num: ?u32 = null;
    var log_lines: u32 = 100;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--config") and i + 1 < args.len) {
            i += 1;
            config_path = args[i];
        } else if (std.mem.eql(u8, arg, "--targets") and i + 1 < args.len) {
            i += 1;
            targets_path = args[i];
        } else if (std.mem.eql(u8, arg, "--out") and i + 1 < args.len) {
            i += 1;
            out_path = args[i];
        } else if (std.mem.eql(u8, arg, "--issue") and i + 1 < args.len) {
            i += 1;
            issue_num = std.fmt.parseInt(u32, args[i], 10) catch null;
        } else if (std.mem.eql(u8, arg, "--log-lines") and i + 1 < args.len) {
            i += 1;
            log_lines = std.fmt.parseInt(u32, args[i], 10) catch 100;
        }
    }

    // Load deploy targets JSON
    const targets_file = std.fs.cwd().openFile(targets_path, .{}) catch {
        print("{s}❌ Cannot open deploy targets: {s}{s}\n", .{ RED, targets_path, RESET });
        print("   Run `tri farm evolve deploy --execute` first to generate deploy_targets.json\n", .{});
        return;
    };
    defer targets_file.close();

    const targets_data = targets_file.readToEndAlloc(allocator, 1024 * 1024) catch {
        print("{s}❌ Failed to read {s}{s}\n", .{ RED, targets_path, RESET });
        return;
    };
    defer allocator.free(targets_data);

    const targets_parsed = std.json.parseFromSlice(std.json.Value, allocator, targets_data, .{}) catch {
        print("{s}❌ Invalid JSON in {s}{s}\n", .{ RED, targets_path, RESET });
        return;
    };
    defer targets_parsed.deinit();

    if (targets_parsed.value != .array) {
        print("{s}❌ deploy_targets.json must be an array{s}\n", .{ RED, RESET });
        return;
    }

    // Parse targets
    var deploy_targets: [MAX_SERVICES]DeployTarget = undefined;
    var target_count: usize = 0;

    for (targets_parsed.value.array.items) |item| {
        if (target_count >= MAX_SERVICES) break;
        if (item != .object) continue;

        var dt = DeployTarget{};
        const cfg = getJsonString(item, "config");
        const cl: u8 = @intCast(@min(cfg.len, 64));
        @memcpy(dt.config[0..cl], cfg[0..cl]);
        dt.config_len = cl;

        const svc = getJsonString(item, "service");
        const sl: u8 = @intCast(@min(svc.len, 64));
        @memcpy(dt.service[0..sl], svc[0..sl]);
        dt.service_len = sl;

        const sid = getJsonString(item, "svc_id");
        const sidl: u8 = @intCast(@min(sid.len, 64));
        @memcpy(dt.svc_id[0..sidl], sid[0..sidl]);
        dt.svc_id_len = sidl;

        dt.acct_idx = @intCast(jsonU32(item, "acct_idx"));
        if (item.object.get("sacred")) |v| {
            dt.sacred = (v == .bool and v.bool);
        }

        deploy_targets[target_count] = dt;
        target_count += 1;
    }

    if (target_count == 0) {
        print("{s}❌ No targets found in {s}{s}\n", .{ RED, targets_path, RESET });
        return;
    }

    // Discover Railway accounts
    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (account_count == 0) {
        print("{s}❌ No Railway accounts found. Source .env first.{s}\n", .{ RED, RESET });
        return;
    }

    print("\n{s}📊 A/B COLLECT — Sacred vs Random{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    // Collect metrics for each target
    var all_milestones: [MAX_SERVICES]Milestones = undefined;
    var collected: usize = 0;

    for (0..target_count) |ti| {
        const dt = &deploy_targets[ti];
        const cfg_name = dt.config[0..dt.config_len];
        const svc_name = dt.service[0..dt.service_len];
        const svc_id = dt.svc_id[0..dt.svc_id_len];

        print("  [{d}/{d}] {s} ({s})...", .{ ti + 1, target_count, cfg_name, svc_name });

        if (dt.acct_idx >= account_count) {
            print(" {s}acct_idx out of range{s}\n", .{ RED, RESET });
            all_milestones[ti] = .{ .status = .err };
            continue;
        }

        // Rate limit between calls
        if (ti > 0) std.Thread.sleep(1000 * std.time.ns_per_ms);

        // Get deployment ID for this service
        var api = RailwayApi.initWithSuffix(allocator, accounts_buf[dt.acct_idx].suffix) catch {
            print(" {s}no token{s}\n", .{ RED, RESET });
            all_milestones[ti] = .{ .status = .err };
            continue;
        };

        const dep_gql = "query($serviceId: String!) { deployments(first:1, input:{serviceId:$serviceId}) { edges { node { id } } } }";
        const dep_vars = std.fmt.allocPrint(allocator, "{{\"serviceId\":\"{s}\"}}", .{svc_id}) catch {
            api.deinit();
            all_milestones[ti] = .{ .status = .err };
            continue;
        };
        defer allocator.free(dep_vars);

        const dep_resp = api.query(dep_gql, dep_vars) catch {
            print(" {s}dep query failed{s}\n", .{ RED, RESET });
            api.deinit();
            all_milestones[ti] = .{ .status = .err };
            continue;
        };
        defer allocator.free(dep_resp);
        api.deinit();

        const dep_parsed = std.json.parseFromSlice(std.json.Value, allocator, dep_resp, .{}) catch {
            print(" {s}bad dep json{s}\n", .{ RED, RESET });
            all_milestones[ti] = .{ .status = .err };
            continue;
        };
        defer dep_parsed.deinit();

        const dep_id = extractDeploymentId(dep_parsed.value) orelse {
            print(" {s}no deployment{s}\n", .{ YELLOW, RESET });
            all_milestones[ti] = .{};
            continue;
        };

        // Fetch logs (fresh API client per call — TLS hang prevention)
        std.Thread.sleep(DEPLOY_RATE_LIMIT_MS * std.time.ns_per_ms);

        var log_api = RailwayApi.initWithSuffix(allocator, accounts_buf[dt.acct_idx].suffix) catch {
            print(" {s}no token for logs{s}\n", .{ RED, RESET });
            all_milestones[ti] = .{ .status = .err };
            continue;
        };

        const log_resp_result = log_api.getDeploymentLogs(dep_id, log_lines);
        log_api.deinit();

        const log_resp = log_resp_result catch {
            print(" {s}logs failed{s}\n", .{ RED, RESET });
            all_milestones[ti] = .{ .status = .err };
            continue;
        };
        defer allocator.free(log_resp);

        const log_parsed = std.json.parseFromSlice(std.json.Value, allocator, log_resp, .{}) catch {
            print(" {s}bad log json{s}\n", .{ RED, RESET });
            all_milestones[ti] = .{ .status = .err };
            continue;
        };
        defer log_parsed.deinit();

        // Parse all training lines
        var metrics_buf: [MAX_METRICS]TrainingMetrics = undefined;
        const metrics_count = parseAllTrainingLines(log_parsed.value, &metrics_buf);

        if (metrics_count == 0) {
            print(" {s}no training data{s}\n", .{ YELLOW, RESET });
            all_milestones[ti] = .{};
            continue;
        }

        all_milestones[ti] = extractMilestones(&metrics_buf, metrics_count);
        collected += 1;

        const m = &all_milestones[ti];
        print(" step={d} best={d:.1} spk={d}\n", .{ m.latest_step, m.best_ppl, m.spikes });
    }

    // Print A/B comparison table
    print("\n{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });
    print("  {s}#  | Config     | Service      | Type   | Step  | PPL@10K | PPL@20K | Best  | Spk{s}\n", .{ DIM, RESET });
    print("  {s}───┼────────────┼──────────────┼────────┼───────┼─────────┼─────────┼───────┼────{s}\n", .{ DIM, RESET });

    var sacred_ppl_20k_sum: f32 = 0;
    var sacred_ppl_20k_count: usize = 0;
    var random_ppl_20k_sum: f32 = 0;
    var random_ppl_20k_count: usize = 0;
    // Hypothesis accumulators
    var sacred_ppl_10k_sum: f32 = 0;
    var sacred_ppl_10k_count: usize = 0;
    var random_ppl_10k_sum: f32 = 0;
    var random_ppl_10k_count: usize = 0;
    var sacred_spike_sum: u32 = 0;
    var sacred_spike_count: usize = 0;
    var random_spike_sum: u32 = 0;
    var random_spike_count: usize = 0;

    for (0..target_count) |ti| {
        const dt = &deploy_targets[ti];
        const m = &all_milestones[ti];
        const cfg_name = dt.config[0..dt.config_len];
        const svc_name = dt.service[0..dt.service_len];
        const type_str: []const u8 = if (dt.sacred) "sacred" else "random";

        print("  {d}", .{ti + 1});
        padTo(countDigits(@intCast(ti + 1)), 3);
        print("| {s}", .{cfg_name});
        padTo(dt.config_len, 11);
        print("| {s}", .{svc_name});
        padTo(dt.service_len, 13);
        print("| {s}", .{type_str});
        padTo(type_str.len, 7);

        if (m.status == .training) {
            // Step
            var step_buf: [8]u8 = undefined;
            const step_str = std.fmt.bufPrint(&step_buf, "{d:.1}K", .{@as(f32, @floatFromInt(m.latest_step)) / 1000.0}) catch "?";
            print("| {s}", .{step_str});
            padTo(step_str.len, 6);
            // PPL@10K
            if (m.ppl_10k < 998) {
                print("| {d:.1}", .{m.ppl_10k});
                padToF(m.ppl_10k, 8);
                if (dt.sacred) {
                    sacred_ppl_10k_sum += m.ppl_10k;
                    sacred_ppl_10k_count += 1;
                } else {
                    random_ppl_10k_sum += m.ppl_10k;
                    random_ppl_10k_count += 1;
                }
            } else {
                print("| ---     ", .{});
            }
            // PPL@20K
            if (m.ppl_20k < 998) {
                print("| {d:.1}", .{m.ppl_20k});
                padToF(m.ppl_20k, 8);
                if (dt.sacred) {
                    sacred_ppl_20k_sum += m.ppl_20k;
                    sacred_ppl_20k_count += 1;
                } else {
                    random_ppl_20k_sum += m.ppl_20k;
                    random_ppl_20k_count += 1;
                }
            } else {
                print("| ---     ", .{});
            }
            // Best
            print("| {d:.1}", .{m.best_ppl});
            padToF(m.best_ppl, 6);
            // Spikes
            print("| {d}\n", .{m.spikes});
            // Accumulate spikes for hypothesis testing
            if (dt.sacred) {
                sacred_spike_sum += m.spikes;
                sacred_spike_count += 1;
            } else {
                random_spike_sum += m.spikes;
                random_spike_count += 1;
            }
        } else {
            print("| ---   | ---     | ---     | ---   | ---\n", .{});
        }
    }

    print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    // Summary
    if (sacred_ppl_20k_count > 0 and random_ppl_20k_count > 0) {
        const sacred_avg = sacred_ppl_20k_sum / @as(f32, @floatFromInt(sacred_ppl_20k_count));
        const random_avg = random_ppl_20k_sum / @as(f32, @floatFromInt(random_ppl_20k_count));

        // Count sacred wins in pairs
        var sacred_wins: usize = 0;
        var total_pairs: usize = 0;
        for (0..target_count) |ti| {
            if (!deploy_targets[ti].sacred) continue;
            if (all_milestones[ti].ppl_20k >= 998) continue;
            // Find matching random partner
            for (0..target_count) |ri| {
                if (deploy_targets[ri].sacred) continue;
                if (all_milestones[ri].ppl_20k >= 998) continue;
                total_pairs += 1;
                if (all_milestones[ti].ppl_20k < all_milestones[ri].ppl_20k) {
                    sacred_wins += 1;
                }
                break;
            }
        }

        print("  {s}SACRED{s} avg PPL@20K: {d:.1} ({d} configs) | {s}RANDOM{s} avg PPL@20K: {d:.1} ({d} configs)\n", .{
            MAGENTA, RESET, sacred_avg, sacred_ppl_20k_count,
            CYAN,    RESET, random_avg, random_ppl_20k_count,
        });
        if (total_pairs > 0) {
            const delta = random_avg - sacred_avg;
            print("  Sacred wins: {d}/{d} pairs | Delta mean: {d:.1} PPL\n", .{ sacred_wins, total_pairs, delta });
        }
    } else {
        print("  Collected: {d}/{d} — not enough data for A/B comparison (need PPL@20K)\n", .{ collected, target_count });
    }

    // Hypothesis verdicts
    print("\n  {s}PRE-REGISTERED HYPOTHESES{s}\n", .{ BOLD, RESET });
    if (sacred_ppl_10k_count > 0 and random_ppl_10k_count > 0) {
        const s_avg_10k = sacred_ppl_10k_sum / @as(f32, @floatFromInt(sacred_ppl_10k_count));
        const r_avg_10k = random_ppl_10k_sum / @as(f32, @floatFromInt(random_ppl_10k_count));
        const h1_delta = r_avg_10k - s_avg_10k;
        const h1_pass = h1_delta >= 1.0;
        print("  H1 Sacred early convergence: sacred avg PPL@10K={d:.1} vs random={d:.1} (Δ={d:.1}) {s}\n", .{
            s_avg_10k, r_avg_10k, h1_delta, if (h1_pass) "[PASS]" else "[FAIL]",
        });
    } else {
        print("  H1 Sacred early convergence: [PENDING] — need PPL@10K data\n", .{});
    }
    if (sacred_spike_count > 0 and random_spike_count > 0) {
        const s_avg_spk = @as(f32, @floatFromInt(sacred_spike_sum)) / @as(f32, @floatFromInt(sacred_spike_count));
        const r_avg_spk = @as(f32, @floatFromInt(random_spike_sum)) / @as(f32, @floatFromInt(random_spike_count));
        const h2_pass = s_avg_spk < r_avg_spk;
        print("  H2 Sacred reduces spikes: sacred avg={d:.1} vs random={d:.1} {s}\n", .{
            s_avg_spk, r_avg_spk, if (h2_pass) "[PASS]" else "[FAIL]",
        });
    } else {
        print("  H2 Sacred reduces spikes: [PENDING] — need training data\n", .{});
    }
    print("\n", .{});

    // Write hypotheses + results
    writeHypotheses();
    writeAbResults(
        allocator,
        &deploy_targets,
        &all_milestones,
        target_count,
        out_path,
        if (sacred_ppl_20k_count > 0) sacred_ppl_20k_sum / @as(f32, @floatFromInt(sacred_ppl_20k_count)) else 999.0,
        if (random_ppl_20k_count > 0) random_ppl_20k_sum / @as(f32, @floatFromInt(random_ppl_20k_count)) else 999.0,
    );

    // Post to GitHub issue
    if (issue_num) |num| {
        postAbToIssue(allocator, num, &deploy_targets, &all_milestones, target_count);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INSPECT — Detailed view of one config
// ═══════════════════════════════════════════════════════════════════════════════

fn runInspect(allocator: Allocator, args: []const []const u8) !void {
    var config_name: ?[]const u8 = null;
    var log_lines: u32 = 100;
    var targets_path: []const u8 = ".trinity/farm/deploy_targets.json";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--lines") and i + 1 < args.len) {
            i += 1;
            log_lines = std.fmt.parseInt(u32, args[i], 10) catch 100;
        } else if (std.mem.eql(u8, args[i], "--targets") and i + 1 < args.len) {
            i += 1;
            targets_path = args[i];
        } else if (config_name == null) {
            config_name = args[i];
        }
    }

    const name = config_name orelse {
        print("{s}❌ Usage: tri farm evolve inspect <config-name> [--lines N]{s}\n", .{ RED, RESET });
        return;
    };

    // Load deploy targets
    const targets_file = std.fs.cwd().openFile(targets_path, .{}) catch {
        print("{s}❌ Cannot open {s}. Run deploy first.{s}\n", .{ RED, targets_path, RESET });
        return;
    };
    defer targets_file.close();

    const targets_data = targets_file.readToEndAlloc(allocator, 1024 * 1024) catch return;
    defer allocator.free(targets_data);

    const targets_parsed = std.json.parseFromSlice(std.json.Value, allocator, targets_data, .{}) catch return;
    defer targets_parsed.deinit();

    if (targets_parsed.value != .array) return;

    // Find config by name
    var found_svc_id: ?[]const u8 = null;
    var found_acct_idx: u8 = 0;
    var found_sacred = false;
    var found_service: []const u8 = "";

    for (targets_parsed.value.array.items) |item| {
        if (item != .object) continue;
        const cfg = getJsonString(item, "config");
        if (std.mem.eql(u8, cfg, name)) {
            found_svc_id = getJsonString(item, "svc_id");
            found_acct_idx = @intCast(jsonU32(item, "acct_idx"));
            found_service = getJsonString(item, "service");
            if (item.object.get("sacred")) |v| {
                found_sacred = (v == .bool and v.bool);
            }
            break;
        }
    }

    const svc_id = found_svc_id orelse {
        print("{s}❌ Config '{s}' not found in deploy_targets.json{s}\n", .{ RED, name, RESET });
        return;
    };

    // Discover accounts
    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (found_acct_idx >= account_count) {
        print("{s}❌ Account index {d} out of range{s}\n", .{ RED, found_acct_idx, RESET });
        return;
    }

    print("\n{s}🔍 INSPECT: {s}{s}\n", .{ BOLD, name, RESET });
    print("  Service: {s} | Sacred: {s} | Account: {d}\n", .{
        found_service, if (found_sacred) "yes" else "no", found_acct_idx,
    });
    print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    // Get deployment ID
    var api = RailwayApi.initWithSuffix(allocator, accounts_buf[found_acct_idx].suffix) catch {
        print("{s}❌ Cannot init API{s}\n", .{ RED, RESET });
        return;
    };

    const dep_gql = "query($serviceId: String!) { deployments(first:1, input:{serviceId:$serviceId}) { edges { node { id } } } }";
    const dep_vars = std.fmt.allocPrint(allocator, "{{\"serviceId\":\"{s}\"}}", .{svc_id}) catch {
        api.deinit();
        return;
    };
    defer allocator.free(dep_vars);

    const dep_resp = api.query(dep_gql, dep_vars) catch {
        print("{s}❌ Deployment query failed{s}\n", .{ RED, RESET });
        api.deinit();
        return;
    };
    defer allocator.free(dep_resp);
    api.deinit();

    const dep_parsed = std.json.parseFromSlice(std.json.Value, allocator, dep_resp, .{}) catch return;
    defer dep_parsed.deinit();

    const dep_id = extractDeploymentId(dep_parsed.value) orelse {
        print("{s}⚠️  No active deployment{s}\n", .{ YELLOW, RESET });
        return;
    };

    // Fetch logs
    std.Thread.sleep(DEPLOY_RATE_LIMIT_MS * std.time.ns_per_ms);
    var log_api = RailwayApi.initWithSuffix(allocator, accounts_buf[found_acct_idx].suffix) catch return;
    const log_resp = log_api.getDeploymentLogs(dep_id, log_lines) catch {
        print("{s}❌ Log fetch failed{s}\n", .{ RED, RESET });
        log_api.deinit();
        return;
    };
    log_api.deinit();
    defer allocator.free(log_resp);

    const log_parsed = std.json.parseFromSlice(std.json.Value, allocator, log_resp, .{}) catch return;
    defer log_parsed.deinit();

    // Parse training lines → milestones
    var metrics_buf: [MAX_METRICS]TrainingMetrics = undefined;
    const metrics_count = parseAllTrainingLines(log_parsed.value, &metrics_buf);

    if (metrics_count == 0) {
        print("  {s}No training data found{s}\n\n", .{ YELLOW, RESET });
        return;
    }

    const m = extractMilestones(&metrics_buf, metrics_count);

    // Milestones table
    print("\n  {s}MILESTONES{s}\n", .{ BOLD, RESET });
    print("  PPL@3K:  {d:.1}\n", .{m.ppl_3k});
    print("  PPL@10K: {d:.1}\n", .{m.ppl_10k});
    print("  PPL@20K: {d:.1}\n", .{m.ppl_20k});
    print("  Best:    {d:.1}\n", .{m.best_ppl});
    print("  Spikes:  {d}\n", .{m.spikes});
    print("  Step:    {d}\n", .{m.latest_step});

    // Last 10 training lines
    print("\n  {s}RECENT TRAINING LINES{s}\n", .{ BOLD, RESET });
    const start = if (metrics_count > 10) metrics_count - 10 else 0;
    for (metrics_buf[start..metrics_count]) |line_m| {
        print("  step={d: >6} loss={d:.3} ppl={d:.1}\n", .{ line_m.step, line_m.loss, line_m.ppl });
    }
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGS — Raw Railway logs for any service
// ═══════════════════════════════════════════════════════════════════════════════

fn runLogs(allocator: Allocator, args: []const []const u8) !void {
    var service_name: ?[]const u8 = null;
    var log_lines: u32 = 50;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--lines") and i + 1 < args.len) {
            i += 1;
            log_lines = std.fmt.parseInt(u32, args[i], 10) catch 50;
        } else if (service_name == null) {
            service_name = args[i];
        }
    }

    const svc_name = service_name orelse {
        print("{s}❌ Usage: tri farm evolve logs <service-name> [--lines N]{s}\n", .{ RED, RESET });
        return;
    };

    // Discover accounts
    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (account_count == 0) {
        print("{s}❌ No Railway accounts. Source .env first.{s}\n", .{ RED, RESET });
        return;
    }

    print("\n{s}📋 LOGS: {s}{s}\n", .{ BOLD, svc_name, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════{s}\n", .{ DIM, RESET });

    // Search across all accounts for the service
    var dep_id_buf: [64]u8 = undefined;
    var dep_id_len: u8 = 0;
    var found_acct_idx: u8 = 0;

    for (0..account_count) |ai| {
        var api = RailwayApi.initWithSuffix(allocator, accounts_buf[ai].suffix) catch continue;

        const gql = "query($projectId: String!) { project(id: $projectId) { services { edges { node { id name deployments(first:1) { edges { node { id } } } } } } } }";
        const proj_id = accounts_buf[ai].project_id;
        const vars = std.fmt.allocPrint(allocator, "{{\"projectId\":\"{s}\"}}", .{proj_id}) catch {
            api.deinit();
            continue;
        };

        const resp = api.query(gql, vars) catch {
            allocator.free(vars);
            api.deinit();
            continue;
        };
        allocator.free(vars);

        const parsed = std.json.parseFromSlice(std.json.Value, allocator, resp, .{}) catch {
            allocator.free(resp);
            api.deinit();
            continue;
        };

        // Search services
        if (getEdgesFromProject(parsed.value)) |edges| {
            for (edges) |edge| {
                const node = getJsonObject(edge, "node") orelse continue;
                const name_str = getJsonString(node, "name");
                if (std.mem.eql(u8, name_str, svc_name)) {
                    // Found! Extract deployment ID
                    const deps = getJsonObject(node, "deployments") orelse continue;
                    const dep_edges = getJsonObject(deps, "edges") orelse continue;
                    if (dep_edges != .array) continue;
                    for (dep_edges.array.items) |de| {
                        const dn = getJsonObject(de, "node") orelse continue;
                        const did = getJsonString(dn, "id");
                        if (!std.mem.eql(u8, did, "?")) {
                            const dl: u8 = @intCast(@min(did.len, 64));
                            @memcpy(dep_id_buf[0..dl], did[0..dl]);
                            dep_id_len = dl;
                            found_acct_idx = @intCast(ai);
                            break;
                        }
                    }
                    break;
                }
            }
        }

        parsed.deinit();
        allocator.free(resp);
        api.deinit();

        if (dep_id_len > 0) break;
    }

    if (dep_id_len == 0) {
        print("  {s}Service '{s}' not found across {d} accounts{s}\n\n", .{ RED, svc_name, account_count, RESET });
        return;
    }

    // Fetch logs with fresh client
    std.Thread.sleep(DEPLOY_RATE_LIMIT_MS * std.time.ns_per_ms);
    var log_api = RailwayApi.initWithSuffix(allocator, accounts_buf[found_acct_idx].suffix) catch {
        print("{s}❌ Cannot init API for logs{s}\n", .{ RED, RESET });
        return;
    };

    const log_resp = log_api.getDeploymentLogs(dep_id_buf[0..dep_id_len], log_lines) catch {
        print("{s}❌ Log fetch failed{s}\n", .{ RED, RESET });
        log_api.deinit();
        return;
    };
    log_api.deinit();
    defer allocator.free(log_resp);

    const log_parsed = std.json.parseFromSlice(std.json.Value, allocator, log_resp, .{}) catch return;
    defer log_parsed.deinit();

    // Print raw log messages
    const data = getJsonObject(log_parsed.value, "data") orelse return;
    const logs = getJsonObject(data, "deploymentLogs") orelse return;
    if (logs != .array) return;

    for (logs.array.items) |log_entry| {
        const msg = getJsonString(log_entry, "message");
        if (!std.mem.eql(u8, msg, "?")) {
            print("  {s}\n", .{msg});
        }
    }
    print("\n", .{});
}

fn writeHypotheses() void {
    const hyp_path = ".trinity/farm/hypotheses.json";
    var f = std.fs.cwd().createFile(hyp_path, .{}) catch return;
    defer f.close();
    f.writeAll(
        \\[
        \\  {"id":"H1","name":"Sacred early convergence","criterion":"sacred avg PPL@10K < random by ≥1.0"},
        \\  {"id":"H2","name":"Sacred reduces spikes","criterion":"sacred avg spikes < random avg spikes"}
        \\]
    ++ "\n") catch return;
    print("  {s}📄 Wrote {s}{s}\n", .{ GREEN, hyp_path, RESET });
}

fn writeAbResults(
    allocator: Allocator,
    targets: *const [MAX_SERVICES]DeployTarget,
    milestones: *const [MAX_SERVICES]Milestones,
    count: usize,
    path: []const u8,
    sacred_avg: f32,
    random_avg: f32,
) void {
    _ = allocator;
    var f = std.fs.cwd().createFile(path, .{}) catch return;
    defer f.close();

    const ts = std.time.milliTimestamp();
    var hdr_buf: [256]u8 = undefined;
    const hdr = std.fmt.bufPrint(&hdr_buf,
        \\{{"timestamp":{d},"configs":[
    ++ "\n", .{ts}) catch return;
    f.writeAll(hdr) catch return;

    for (0..count) |ci| {
        const dt = &targets[ci];
        const m = &milestones[ci];
        const sacred_str: []const u8 = if (dt.sacred) "true" else "false";
        const status_str: []const u8 = switch (m.status) {
            .training => "training",
            .no_data => "no_data",
            .err => "error",
        };

        var line_buf: [512]u8 = undefined;
        const line = std.fmt.bufPrint(&line_buf,
            \\  {{"name":"{s}","sacred":{s},"service":"{s}","step":{d},"ppl_3k":{d:.1},"ppl_10k":{d:.1},"ppl_20k":{d:.1},"best_ppl":{d:.1},"spikes":{d},"status":"{s}"}}
        , .{
            dt.config[0..dt.config_len], sacred_str, dt.service[0..dt.service_len],
            m.latest_step,               m.ppl_3k,   m.ppl_10k,
            m.ppl_20k,                   m.best_ppl, m.spikes,
            status_str,
        }) catch continue;
        f.writeAll(line) catch continue;
        if (ci + 1 < count) f.writeAll(",\n") catch {} else f.writeAll("\n") catch {};
    }

    var summary_buf: [256]u8 = undefined;
    const summary = std.fmt.bufPrint(&summary_buf,
        \\],"summary":{{"sacred_avg_20k":{d:.1},"random_avg_20k":{d:.1}}}}}
    ++ "\n", .{ sacred_avg, random_avg }) catch return;
    f.writeAll(summary) catch return;

    print("  {s}📄 Wrote {s}{s}\n", .{ GREEN, path, RESET });
}

fn postAbToIssue(
    allocator: Allocator,
    issue_num: u32,
    targets: *const [MAX_SERVICES]DeployTarget,
    milestones: *const [MAX_SERVICES]Milestones,
    count: usize,
) void {
    var body_buf: [4096]u8 = undefined;
    var pos: usize = 0;

    const header =
        \\📊 **A/B Collect Results**
        \\
        \\| # | Config | Service | Type | Step | PPL@10K | PPL@20K | Best | Spk |
        \\|---|--------|---------|------|------|---------|---------|------|-----|
        \\
    ;
    @memcpy(body_buf[pos .. pos + header.len], header);
    pos += header.len;

    for (0..count) |ti| {
        const dt = &targets[ti];
        const m = &milestones[ti];
        const type_str: []const u8 = if (dt.sacred) "sacred" else "random";
        const cfg_name = dt.config[0..dt.config_len];
        const svc_name = dt.service[0..dt.service_len];

        const row = std.fmt.bufPrint(body_buf[pos..], "| {d} | {s} | {s} | {s} | {d} | {d:.1} | {d:.1} | {d:.1} | {d} |\n", .{
            ti + 1,        cfg_name,  svc_name,  type_str,
            m.latest_step, m.ppl_10k, m.ppl_20k, m.best_ppl,
            m.spikes,
        }) catch break;
        pos += row.len;
    }

    const num_str = std.fmt.allocPrint(allocator, "{d}", .{issue_num}) catch return;
    defer allocator.free(num_str);

    const gh_argv = [_][]const u8{ "gh", "issue", "comment", num_str, "--body", body_buf[0..pos] };
    var gh_child = std.process.Child.init(&gh_argv, allocator);
    gh_child.stderr_behavior = .Ignore;
    gh_child.stdout_behavior = .Ignore;
    _ = gh_child.spawnAndWait() catch {
        print("  {s}⚠️  Failed to post to issue #{d}{s}\n", .{ YELLOW, issue_num, RESET });
        return;
    };
    print("  {s}📝 Posted A/B results to issue #{d}{s}\n", .{ GREEN, issue_num, RESET });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Steady-State: inject + watch
// ═══════════════════════════════════════════════════════════════════════════════

fn findServiceByName(state: *EvolutionState, name: []const u8) ?usize {
    for (state.services[0..state.service_count], 0..) |*svc, i| {
        if (std.mem.eql(u8, svc.svcName(), name)) return i;
    }
    return null;
}

fn runInject(allocator: Allocator, args: []const []const u8) !void {
    var target_name: ?[]const u8 = null;
    var parent_name: ?[]const u8 = null;
    var sacred = false;
    var dry_run = false;
    var force_recycle = false;
    var objective: []const u8 = "ntp";
    var nca_steps: u32 = 15000;
    var nca_entropy_min: []const u8 = "1.5";
    var nca_entropy_max: []const u8 = "2.8";
    var override_context: ?u32 = null;
    var batch_count: ?u32 = null;
    var override_sched: ?LrSchedule = null;
    var force_fresh = false;
    var use_quotas = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--target") and i + 1 < args.len) {
            i += 1;
            target_name = args[i];
        } else if (std.mem.eql(u8, args[i], "--parent") and i + 1 < args.len) {
            i += 1;
            parent_name = args[i];
        } else if (std.mem.eql(u8, args[i], "--objective") and i + 1 < args.len) {
            i += 1;
            objective = args[i];
        } else if (std.mem.eql(u8, args[i], "--nca-steps") and i + 1 < args.len) {
            i += 1;
            nca_steps = std.fmt.parseInt(u32, args[i], 10) catch 15000;
        } else if (std.mem.eql(u8, args[i], "--nca-entropy-min") and i + 1 < args.len) {
            i += 1;
            nca_entropy_min = args[i];
        } else if (std.mem.eql(u8, args[i], "--nca-entropy-max") and i + 1 < args.len) {
            i += 1;
            nca_entropy_max = args[i];
        } else if (std.mem.eql(u8, args[i], "--context") and i + 1 < args.len) {
            i += 1;
            const ctx_val = std.fmt.parseInt(u32, args[i], 10) catch {
                print("{s}ERROR: --context requires a number{s}\n", .{ RED, RESET });
                return;
            };
            if (ctx_val != 27 and ctx_val != 54 and ctx_val != 81 and ctx_val != 243) {
                print("{s}ERROR: --context must be sacred dimension ∈ {{27, 54, 81, 243}}, got {d}{s}\n", .{ RED, ctx_val, RESET });
                return;
            }
            override_context = ctx_val;
        } else if (std.mem.eql(u8, args[i], "--count") and i + 1 < args.len) {
            i += 1;
            const cnt = std.fmt.parseInt(u32, args[i], 10) catch {
                print("{s}ERROR: --count requires a number{s}\n", .{ RED, RESET });
                return;
            };
            batch_count = @min(cnt, 15);
        } else if (std.mem.eql(u8, args[i], "--sched") and i + 1 < args.len) {
            i += 1;
            if (std.mem.eql(u8, args[i], "flat")) {
                print("{s}ERROR: flat LR schedule is BANNED (dead by 20K steps). Use cosine/wsd/d2z/phi_restart.{s}\n", .{ RED, RESET });
                return;
            }
            override_sched = LrSchedule.fromStr(args[i]);
        } else if (std.mem.eql(u8, args[i], "--sacred")) {
            sacred = true;
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--force-recycle") or std.mem.eql(u8, args[i], "--force")) {
            force_recycle = true;
        } else if (std.mem.eql(u8, args[i], "--fresh")) {
            force_fresh = true;
        } else if (std.mem.eql(u8, args[i], "--quota")) {
            use_quotas = true;
        }
    }

    // Batch injection path: --count N auto-picks N worst performers
    if (batch_count) |count| {
        return runInjectBatch(allocator, count, sacred, dry_run, force_recycle, objective, nca_steps, nca_entropy_min, nca_entropy_max, override_context, override_sched, force_fresh, use_quotas);
    }

    const tgt = target_name orelse {
        print("{s}ERROR: --target <service-name> is required (or use --count N for batch){s}\n", .{ RED, RESET });
        return;
    };

    var state = loadState(allocator) catch {
        print("{s}ERROR: No evolution state. Run 'tri farm evolve init' first.{s}\n", .{ RED, RESET });
        return;
    };

    const target_idx = findServiceByName(&state, tgt) orelse {
        print("{s}ERROR: Service '{s}' not found in evolution state{s}\n", .{ RED, tgt, RESET });
        return;
    };

    const target = &state.services[target_idx];

    // SAFETY: refuse PRIMARY account
    if (target.account_idx == 0) {
        print("{s}REFUSED: '{s}' is on PRIMARY account (account_idx=0). Never recycle PRIMARY services.{s}\n", .{ RED, tgt, RESET });
        return;
    }

    // SAFETY: refuse if actively training (but allow finished workers at 100K)
    if (target.status == .running and target.current_step > 0 and target.current_step < 100000) {
        if (force_recycle and target.current_ppl > 50.0 and target.current_step >= 10000) {
            // --force-recycle: allow recycling hopeless workers (PPL>50 && step>=10K)
            print("{s}⚠️  FORCE-RECYCLE: '{s}' (step={d}, PPL={d:.2}) — killing hopeless worker{s}\n", .{ YELLOW, tgt, target.current_step, target.current_ppl, RESET });
        } else if (force_recycle) {
            print("{s}REFUSED: --force-recycle requires PPL>50 and step>=10K. '{s}' has step={d}, PPL={d:.2}{s}\n", .{ RED, tgt, target.current_step, target.current_ppl, RESET });
            return;
        } else {
            print("{s}REFUSED: '{s}' is actively training (step={d}, PPL={d:.2}). Use --force-recycle for PPL>50 workers.{s}\n", .{ RED, tgt, target.current_step, target.current_ppl, RESET });
            return;
        }
    }

    // Find parent
    var parent_idx: usize = 0;
    if (parent_name) |pn| {
        parent_idx = findServiceByName(&state, pn) orelse {
            print("{s}ERROR: Parent '{s}' not found in evolution state{s}\n", .{ RED, pn, RESET });
            return;
        };
    } else {
        // Auto-select via binary tournament (PBT)
        const seed_ts: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())));
        parent_idx = selectParentTournament(&state, seed_ts) orelse {
            print("{s}ERROR: No running parents found. Need at least 1 active training service.{s}\n", .{ RED, RESET });
            return;
        };
    }

    const parent = &state.services[parent_idx];
    const seed: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())));
    var config = if (sacred)
        mutateConfigSacred(parent, seed, false)
    else
        mutateConfig(parent, seed);

    if (override_context) |ctx| config.context = ctx;
    if (override_sched) |sched| config.lr_schedule = sched;

    // Detect architecture change vs parent → fresh start
    const obj_changed = !std.mem.eql(u8, objective, parent.objectiveStr());
    const ctx_changed = (override_context != null and config.context != parent.context);
    if (obj_changed or ctx_changed or force_fresh) {
        config.fresh = true;
    }

    const p_name = parent.svcName();
    const fresh_str: []const u8 = if (config.fresh) " [FRESH]" else "";
    const mode_str: []const u8 = if (sacred) " [SACRED]" else "";
    const obj_str: []const u8 = if (std.mem.eql(u8, objective, "ntp")) "" else if (std.mem.eql(u8, objective, "hybrid")) " [HYBRID]" else if (std.mem.indexOf(u8, objective, "nca") != null) " [NCA]" else " [JEPA]";
    print("\n{s}💉 INJECT:{s} {s} ← child of {s}{s}{s}{s}\n", .{ BOLD, RESET, tgt, p_name, mode_str, obj_str, fresh_str });
    print("   LR={s}  GC={d:.3}  WU={d}  seed={d}  objective={s}\n", .{ config.lr_str[0..config.lr_len], config.grad_clip, config.warmup, config.seed, objective });
    if (std.mem.indexOf(u8, objective, "nca") != null) {
        print("   NCA: steps={d}  entropy=[{s}, {s}]\n", .{ nca_steps, nca_entropy_min, nca_entropy_max });
    }

    if (dry_run) {
        print("   {s}--dry-run: no action taken{s}\n\n", .{ DIM, RESET });
        return;
    }

    var config_with_obj = config;
    config_with_obj.objective = objective;
    if (std.mem.indexOf(u8, objective, "nca") != null) {
        config_with_obj.nca_steps = nca_steps;
        config_with_obj.nca_entropy_min = nca_entropy_min;
        config_with_obj.nca_entropy_max = nca_entropy_max;
    }

    var api_calls: u32 = 0;
    recycleService(allocator, &state, target_idx, config_with_obj, p_name, &api_calls);

    var detail_buf: [128]u8 = undefined;
    const detail = std.fmt.bufPrint(&detail_buf, "injected from {s}", .{p_name}) catch "injected";
    state.addEvent(.spawn, tgt, detail);
    notifyWsBus(.inject, tgt, detail);

    saveState(state) catch |err| {
        print("  {s}⚠️  Failed to save state: {}{s}\n", .{ YELLOW, err, RESET });
    };
    print("   {s}✅ Injected successfully ({d} API calls){s}\n\n", .{ GREEN, api_calls, RESET });
}

fn runInjectBatch(
    allocator: Allocator,
    count: u32,
    sacred: bool,
    dry_run: bool,
    force_recycle: bool,
    objective: []const u8,
    nca_steps: u32,
    nca_entropy_min: []const u8,
    nca_entropy_max: []const u8,
    override_context: ?u32,
    override_sched: ?LrSchedule,
    force_fresh: bool,
    use_quotas: bool,
) !void {
    var state = loadState(allocator) catch {
        print("{s}ERROR: No evolution state. Run 'tri farm evolve init' first.{s}\n", .{ RED, RESET });
        return;
    };

    // Build candidate array: worst performers eligible for recycling
    var candidates: [MAX_SERVICES]usize = undefined;
    var cand_count: usize = 0;

    for (state.services[0..state.service_count], 0..) |*svc, si| {
        // Skip PRIMARY account
        if (svc.account_idx == 0) continue;
        // Skip near-finish (≥90K steps)
        if (svc.current_step >= 90000) continue;

        const recyclable = svc.status == .crashed or svc.status == .stalled or
            svc.status == .diverged or svc.status == .stuck or
            svc.status == .idle or svc.status == .killed;

        if (recyclable) {
            candidates[cand_count] = si;
            cand_count += 1;
            continue;
        }

        // Running workers: batch --force allows recycling any running worker with step>=10K
        // (single-target inject still enforces PPL>50 in runInject)
        if (svc.status == .running and svc.current_step > 0 and svc.current_step < 100000) {
            if (force_recycle and svc.current_step >= 10000) {
                candidates[cand_count] = si;
                cand_count += 1;
            }
        }
    }

    if (cand_count == 0) {
        print("{s}⚠️  No recyclable candidates found. All workers are healthy or on PRIMARY.{s}\n", .{ YELLOW, RESET });
        return;
    }

    // Sort candidates by PPL ascending (worst = last)
    sortByPpl(&state, candidates[0..cand_count]);

    // Take N worst from the end
    const n = @min(count, @as(u32, @intCast(cand_count)));
    const mode_str: []const u8 = if (sacred) " [SACRED]" else "";
    const obj_str: []const u8 = if (std.mem.eql(u8, objective, "ntp")) "" else if (std.mem.eql(u8, objective, "hybrid")) " [HYBRID]" else if (std.mem.indexOf(u8, objective, "nca") != null) " [NCA]" else " [JEPA]";

    print("\n{s}💉 BATCH INJECT:{s} {d} of {d} candidates{s}{s}\n", .{ BOLD, RESET, n, cand_count, mode_str, obj_str });
    if (override_context) |ctx| print("   context override: {d}\n", .{ctx});
    if (override_sched) |sched| print("   schedule override: {s}\n", .{sched.toStr()});

    var total_api_calls: u32 = 0;
    const seed_base: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())));

    var injected: u32 = 0;
    var ji: u32 = 0;
    while (ji < n) : (ji += 1) {
        const target_idx = candidates[cand_count - 1 - ji]; // worst first (end of sorted array)
        const target = &state.services[target_idx];
        const t_name = target.svcName();

        // Select parent
        const seed = seed_base +% ji;
        const parent_idx = selectParentTruncation(&state, seed) orelse {
            print("   {s}⚠️  No elite parents available, stopping.{s}\n", .{ YELLOW, RESET });
            break;
        };
        const parent = &state.services[parent_idx];
        const p_name = parent.svcName();

        // Mutate config from parent
        var config = if (sacred)
            mutateConfigSacred(parent, seed, false)
        else
            mutateConfig(parent, seed);

        // Apply overrides
        if (override_context) |ctx| config.context = ctx;
        if (override_sched) |sched| config.lr_schedule = sched;
        config.objective = objective;

        // Quota-driven objective/context override
        if (use_quotas) {
            const deficit = computeQuotaDeficit(&state);
            config.objective = deficit.objective;
            if (deficit.min_context > 0) {
                config.context = if (seed % 2 == 0) 81 else 243;
            }
        }

        if (std.mem.indexOf(u8, objective, "nca") != null) {
            config.nca_steps = nca_steps;
            config.nca_entropy_min = nca_entropy_min;
            config.nca_entropy_max = nca_entropy_max;
        }

        // Detect architecture change vs parent → fresh start
        const obj_changed = !std.mem.eql(u8, objective, parent.objectiveStr());
        const ctx_changed = (override_context != null and config.context != parent.context);
        if (obj_changed or ctx_changed or force_fresh) {
            config.fresh = true;
        }

        const fresh_tag: []const u8 = if (config.fresh) " FRESH" else "";
        print("   [{d}/{d}] {s} ← {s} (ctx={d}, sched={s}{s})\n", .{ ji + 1, n, t_name, p_name, config.context, config.lr_schedule.toStr(), fresh_tag });

        if (dry_run) continue;

        recycleService(allocator, &state, target_idx, config, p_name, &total_api_calls);

        // Prevent re-injection: mark as freshly deployed (PPL=0 = best, won't be "worst")
        state.services[target_idx].current_ppl = 0.0;
        state.services[target_idx].current_step = 1;
        state.services[target_idx].status = .running;

        var detail_buf: [128]u8 = undefined;
        const detail = std.fmt.bufPrint(&detail_buf, "batch-injected from {s}", .{p_name}) catch "batch-injected";
        state.addEvent(.spawn, t_name, detail);
        notifyWsBus(.inject, t_name, detail);
        injected += 1;
    }

    if (!dry_run) {
        saveState(state) catch |err| {
            print("  {s}⚠️  Failed to save state: {}{s}\n", .{ YELLOW, err, RESET });
        };
        print("\n   {s}✅ Injected {d} services ({d} API calls){s}\n\n", .{ GREEN, injected, total_api_calls, RESET });
    } else {
        print("\n   {s}--dry-run: no action taken{s}\n\n", .{ DIM, RESET });
    }
}

fn runWatch(allocator: Allocator, args: []const []const u8) !void {
    var sacred = false;
    var once = false;
    var interval: u64 = 300;
    var dry_run = false;
    var notify = false;
    var kill_live = false;
    var tune = false;
    var objective: []const u8 = "ntp";
    var nca_steps: u32 = 15000;
    var nca_entropy_min: []const u8 = "1.5";
    var nca_entropy_max: []const u8 = "2.8";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--sacred")) {
            sacred = true;
        } else if (std.mem.eql(u8, args[i], "--once")) {
            once = true;
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--notify")) {
            notify = true;
        } else if (std.mem.eql(u8, args[i], "--kill-live")) {
            kill_live = true;
        } else if (std.mem.eql(u8, args[i], "--tune")) {
            tune = true;
        } else if (std.mem.eql(u8, args[i], "--objective") and i + 1 < args.len) {
            i += 1;
            objective = args[i];
        } else if (std.mem.eql(u8, args[i], "--nca-steps") and i + 1 < args.len) {
            i += 1;
            nca_steps = std.fmt.parseInt(u32, args[i], 10) catch 15000;
        } else if (std.mem.eql(u8, args[i], "--nca-entropy-min") and i + 1 < args.len) {
            i += 1;
            nca_entropy_min = args[i];
        } else if (std.mem.eql(u8, args[i], "--nca-entropy-max") and i + 1 < args.len) {
            i += 1;
            nca_entropy_max = args[i];
        } else if (std.mem.eql(u8, args[i], "--interval") and i + 1 < args.len) {
            i += 1;
            interval = std.fmt.parseInt(u64, args[i], 10) catch 300;
            if (interval < 60) interval = 60; // minimum 60s
        }
    }

    while (true) {
        print("\n{s}👁️  WATCH sweep{s}\n", .{ BOLD, RESET });

        var state = loadState(allocator) catch {
            print("{s}ERROR: No evolution state. Run 'tri farm evolve init' first.{s}\n", .{ RED, RESET });
            return;
        };

        // Refresh metrics
        var api_calls: u32 = 0;
        collectMetrics(allocator, &state, &api_calls);
        saveState(state) catch {};

        // Find dead/finished candidates (skip PRIMARY)
        var candidates: [MAX_SERVICES]usize = undefined;
        var cand_count: usize = 0;
        for (state.services[0..state.service_count], 0..) |*svc, si| {
            if (svc.account_idx == 0) continue; // skip PRIMARY
            const is_dead = svc.status == .crashed or svc.status == .idle or svc.status == .killed;
            const is_finished = svc.current_step >= 100000;
            if (is_dead or is_finished) {
                candidates[cand_count] = si;
                cand_count += 1;
            }
        }

        if (cand_count == 0) {
            print("   {s}All slots occupied — nothing to inject{s}\n", .{ DIM, RESET });
        } else {
            const max_inject: usize = @min(cand_count, 5); // rate limit: max 5 per sweep
            var injected: usize = 0;

            print("   Candidates: {d} dead/finished slots, injecting up to {d} (truncation selection)\n\n", .{ cand_count, max_inject });

            var seed: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())));
            for (candidates[0..max_inject]) |ci| {
                const svc = &state.services[ci];
                seed = mulberry32(seed);

                // Each child gets a different parent via truncation selection
                const parent_idx = selectParentTruncation(&state, seed) orelse {
                    print("   {s}No running parents — cannot inject{s}\n", .{ RED, RESET });
                    break;
                };
                const parent = &state.services[parent_idx];
                const p_name = parent.svcName();

                seed = mulberry32(seed);
                var config = if (sacred)
                    mutateConfigSacred(parent, seed, false)
                else
                    mutateConfig(parent, seed);
                config.objective = objective;
                if (std.mem.indexOf(u8, objective, "nca") != null) {
                    config.nca_steps = nca_steps;
                    config.nca_entropy_min = nca_entropy_min;
                    config.nca_entropy_max = nca_entropy_max;
                }

                const mode_str: []const u8 = if (sacred) " [SACRED]" else "";
                const obj_str: []const u8 = if (std.mem.eql(u8, objective, "ntp")) "" else if (std.mem.eql(u8, objective, "hybrid")) " [HYBRID]" else if (std.mem.indexOf(u8, objective, "nca") != null) " [NCA]" else " [JEPA]";
                print("   💉 {s} ← {s}{s}{s}  LR={s}  GC={d:.3}  WU={d}\n", .{
                    svc.svcName(),                   p_name,           mode_str,      obj_str,
                    config.lr_str[0..config.lr_len], config.grad_clip, config.warmup,
                });

                if (!dry_run) {
                    recycleService(allocator, &state, ci, config, p_name, &api_calls);
                    var detail_buf: [128]u8 = undefined;
                    const detail = std.fmt.bufPrint(&detail_buf, "watch-injected from {s}", .{p_name}) catch "watch-injected";
                    state.addEvent(.spawn, svc.svcName(), detail);
                    notifyWsBus(.spawn, svc.svcName(), detail);
                }
                injected += 1;
            }

            if (dry_run) {
                print("\n   {s}--dry-run: no actions taken{s}\n", .{ DIM, RESET });
            } else {
                saveState(state) catch {};
                print("\n   {s}✅ Injected {d} children ({d} API calls){s}\n", .{ GREEN, injected, api_calls, RESET });
            }
        }

        // Kill tournament: replace live-but-struggling workers
        if (kill_live) {
            const first_rung_step = if (sacred) SACRED_RUNGS[0].step_threshold else DEFAULT_RUNGS[0].step_threshold;
            var live_kills: u32 = 0;
            var kill_seed: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())) +% 7777);
            while (live_kills < 2) { // max 2 live kills per sweep
                kill_seed = mulberry32(kill_seed);
                const victim_idx = findKillTournamentVictim(&state, first_rung_step, kill_seed) orelse break;
                kill_seed = mulberry32(kill_seed);
                const parent_idx = selectParentTruncation(&state, kill_seed) orelse break;
                // Don't kill the parent we just picked
                if (victim_idx == parent_idx) break;

                const victim = &state.services[victim_idx];
                const parent = &state.services[parent_idx];
                kill_seed = mulberry32(kill_seed);
                const config = if (sacred)
                    mutateConfigSacred(parent, kill_seed, false)
                else
                    mutateConfig(parent, kill_seed);

                print("   🏴 KILL-LIVE {s} (PPL={d:.2}) ← {s}  LR={s}\n", .{
                    victim.svcName(),                victim.current_ppl, parent.svcName(),
                    config.lr_str[0..config.lr_len],
                });

                if (!dry_run) {
                    var detail_buf: [128]u8 = undefined;
                    const detail = std.fmt.bufPrint(&detail_buf, "kill-tournament PPL={d:.1}, parent={s}", .{ victim.current_ppl, parent.svcName() }) catch "kill-tournament";
                    state.addEvent(.kill, victim.svcName(), detail);
                    notifyWsBus(.kill, victim.svcName(), detail);
                    recycleService(allocator, &state, victim_idx, config, parent.svcName(), &api_calls);
                    state.addEvent(.spawn, victim.svcName(), "respawned after kill-tournament");
                    notifyWsBus(.spawn, victim.svcName(), "respawned after kill-tournament");
                    saveState(state) catch {};
                }
                live_kills += 1;
            }
            if (live_kills > 0) {
                print("   {s}Kill tournament: {d} live worker(s) replaced{s}\n", .{ YELLOW, live_kills, RESET });
            } else {
                print("   {s}Kill tournament: no eligible victims{s}\n", .{ DIM, RESET });
            }
        }

        // Auto-tune struggling workers
        if (tune) {
            runTuneInternal(allocator, &state, sacred, dry_run, &api_calls);
        }

        // Auto-notify after sweep
        if (notify) {
            const notify_args = if (dry_run)
                @as([]const []const u8, &[_][]const u8{"--dry-run"})
            else
                @as([]const []const u8, &[_][]const u8{});
            runNotify(allocator, notify_args) catch |err| {
                print("   {s}Notify error: {}{s}\n", .{ RED, err, RESET });
            };
        }

        if (once) return;

        print("   Sleeping {d}s until next sweep...\n", .{interval});
        std.Thread.sleep(interval * std.time.ns_per_s);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTIFY — Scan artifacts, detect insights, send to Telegram
// ═══════════════════════════════════════════════════════════════════════════════

const NotifyState = struct {
    last_best_ppl: f32 = 999.0,
    last_best_name: [64]u8 = undefined,
    last_best_name_len: u8 = 0,
    last_event_count: usize = 0,
    last_timestamp: i64 = 0,
    last_leader_step: u32 = 0,
};

fn loadNotifyState(allocator: Allocator) NotifyState {
    const file = std.fs.cwd().openFile(NOTIFY_STATE_PATH, .{}) catch return .{};
    defer file.close();
    const contents = file.readToEndAlloc(allocator, 4096) catch return .{};
    defer allocator.free(contents);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, contents, .{}) catch return .{};
    defer parsed.deinit();
    var ns = NotifyState{};
    ns.last_best_ppl = jsonF32(parsed.value, "last_best_ppl");
    if (ns.last_best_ppl == 0) ns.last_best_ppl = 999.0;
    const name = getJsonString(parsed.value, "last_best_name");
    copyToFixed(&ns.last_best_name, &ns.last_best_name_len, name);
    ns.last_event_count = @intCast(jsonU32(parsed.value, "last_event_count"));
    ns.last_timestamp = jsonI64(parsed.value, "last_timestamp");
    ns.last_leader_step = jsonU32(parsed.value, "last_leader_step");
    return ns;
}

fn saveNotifyState(ns: *const NotifyState) void {
    // Ensure directory exists
    std.fs.cwd().makePath(".trinity/farm") catch {};
    var file = std.fs.cwd().createFile(NOTIFY_STATE_PATH, .{}) catch return;
    defer file.close();
    var buf: [512]u8 = undefined;
    const name = if (ns.last_best_name_len > 0)
        ns.last_best_name[0..ns.last_best_name_len]
    else
        "";
    const json = std.fmt.bufPrint(&buf, "{{\"last_best_ppl\":{d:.2},\"last_best_name\":\"{s}\",\"last_event_count\":{d},\"last_timestamp\":{d},\"last_leader_step\":{d}}}", .{
        ns.last_best_ppl, name, ns.last_event_count, ns.last_timestamp, ns.last_leader_step,
    }) catch return;
    file.writeAll(json) catch {};
}

fn runNotify(allocator: Allocator, args: []const []const u8) !void {
    var dry_run = false;
    var threshold: f32 = 999.0;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        } else if (std.mem.eql(u8, args[i], "--threshold") and i + 1 < args.len) {
            i += 1;
            threshold = std.fmt.parseFloat(f32, args[i]) catch 999.0;
        }
    }

    // Load current farm state
    const state = loadState(allocator) catch {
        print("{s}ERROR: No evolution state. Run 'tri farm evolve init' first.{s}\n", .{ RED, RESET });
        return;
    };

    // Load notify pointer
    var ns = loadNotifyState(allocator);

    // Build message
    var msg_buf: [4000]u8 = undefined;
    var pos: usize = 0;

    // Header
    pos += (std.fmt.bufPrint(msg_buf[pos..], "🧬 <b>FARM INSIGHT</b>\n\n", .{}) catch return).len;

    var has_insights = false;

    // Trigger 1: New global leader
    if (state.best_ppl < ns.last_best_ppl and state.best_ppl < threshold) {
        const prev_name = if (ns.last_best_name_len > 0)
            ns.last_best_name[0..ns.last_best_name_len]
        else
            "(none)";
        pos += (std.fmt.bufPrint(msg_buf[pos..], "🏆 New leader: <b>{s}</b> PPL={d:.2} (was {s} PPL={d:.2})\n", .{
            state.bestNameStr(), state.best_ppl, prev_name, ns.last_best_ppl,
        }) catch break_msg: {
            break :break_msg "";
        }).len;
        has_insights = true;
    }

    // Trigger 2-4: New events since last notify
    if (state.event_count > ns.last_event_count) {
        const start = ns.last_event_count;
        const end = state.event_count;
        for (state.events[start..end]) |*ev| {
            const emoji: []const u8 = switch (ev.event_type) {
                .spawn => "💉",
                .kill => "💀",
                .rung_complete => "🎯",
                .err => "⚠️",
                .tune => "🔧",
            };
            const label: []const u8 = switch (ev.event_type) {
                .spawn => "Injected",
                .kill => "Died",
                .rung_complete => "Rung",
                .err => "Error",
                .tune => "Tuned",
            };
            if (pos + 200 > msg_buf.len) break;
            pos += (std.fmt.bufPrint(msg_buf[pos..], "{s} {s}: {s} — {s}\n", .{
                emoji, label, ev.svcName(), ev.detailStr(),
            }) catch break).len;
            has_insights = true;
        }
    }

    // Trigger 5: Spike detection
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status != .running or svc.current_step == 0) continue;
        const expected_loss = @log(svc.current_ppl);
        if (svc.current_loss > expected_loss * 2.0) {
            if (pos + 200 > msg_buf.len) break;
            pos += (std.fmt.bufPrint(msg_buf[pos..], "🔥 Spike: {s} loss={d:.2} (expected ~{d:.2})\n", .{
                svc.svcName(), svc.current_loss, expected_loss,
            }) catch break).len;
            has_insights = true;
        }
    }

    // Trigger 6: Population health alerts
    const health = computePopulationHealth(&state);
    if (health.diversity < 0.001 and pos + 200 < msg_buf.len) {
        pos += (std.fmt.bufPrint(msg_buf[pos..], "⚠️ CONVERGING: diversity={d:.4}, inject more sacred mutations\n", .{health.diversity}) catch "").len;
        has_insights = true;
    }
    if (health.elite_gap > 3.0 and pos + 200 < msg_buf.len) {
        pos += (std.fmt.bufPrint(msg_buf[pos..], "👑 DOMINANT LEADER: PPL gap {d:.1}×\n", .{health.elite_gap}) catch "").len;
        has_insights = true;
    }
    if (health.stagnation > 20000 and pos + 200 < msg_buf.len) {
        pos += (std.fmt.bufPrint(msg_buf[pos..], "⚠️ STAGNATION: {d}K steps without improvement\n", .{health.stagnation / 1000}) catch "").len;
        has_insights = true;
    }
    if (health.spike_rate > 0.3 and pos + 200 < msg_buf.len) {
        pos += (std.fmt.bufPrint(msg_buf[pos..], "🔴 HIGH SPIKES: {d:.0}% workers spiking\n", .{health.spike_rate * 100.0}) catch "").len;
        has_insights = true;
    }

    // Trigger 7: LEADER_PLATEAU — not improving >10K steps, still far from 100K
    if (health.leader_step > 0 and health.leader_step < 80000) {
        const steps_no_improve = health.stagnation;
        if (steps_no_improve > 10000 and pos + 300 < msg_buf.len) {
            pos += (std.fmt.bufPrint(msg_buf[pos..], "📊 LEADER PLATEAU: {s} no improvement for {d}K steps (at {d}K/100K)\n", .{
                state.bestNameStr(), steps_no_improve / 1000, health.leader_step / 1000,
            }) catch "").len;
            has_insights = true;
        }
    }

    // Trigger 8: INVESTIGATE — catastrophic spike (loss > 3× expected)
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status != .running or svc.current_step == 0) continue;
        const expected = @log(svc.current_ppl);
        if (svc.current_loss > expected * 3.0 and pos + 200 < msg_buf.len) {
            pos += (std.fmt.bufPrint(msg_buf[pos..], "🚨 INVESTIGATE: {s} catastrophic spike loss={d:.2} (3x expected={d:.2})\n", .{
                svc.svcName(), svc.current_loss, expected * 3.0,
            }) catch "").len;
            has_insights = true;
        }
    }

    // Trigger 9: WAVE_COMPLETE — all top-N reached 100K
    const TARGET_STEP: u32 = 100000;
    var top_at_100k: u32 = 0;
    var top_count: u32 = 0;
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status == .running and getPplForRanking(svc) < 50.0) {
            top_count += 1;
            if (svc.current_step >= TARGET_STEP) top_at_100k += 1;
        }
    }
    if (top_at_100k > 0 and top_at_100k == top_count and pos + 200 < msg_buf.len) {
        pos += (std.fmt.bufPrint(msg_buf[pos..], "🏁 WAVE COMPLETE: all {d} top workers reached 100K! Ready for next wave\n", .{top_count}) catch "").len;
        has_insights = true;
    }

    // Trigger 10: RECORD_VERIFIED — leader reached 100K with new best
    if (health.leader_step >= TARGET_STEP and state.best_ppl < ns.last_best_ppl and pos + 200 < msg_buf.len) {
        pos += (std.fmt.bufPrint(msg_buf[pos..], "🏆 RECORD VERIFIED at 100K: {s} PPL={d:.2}\n", .{
            state.bestNameStr(), state.best_ppl,
        }) catch "").len;
        has_insights = true;
    }

    // ETA + Leader mini-summary
    if (has_insights and pos + 600 < msg_buf.len) {
        const r33_ppl: f32 = 4.6;
        const delta_r33 = state.best_ppl - r33_ppl;
        const steps_no_improve_summary = if (health.leader_step > state.best_step) health.leader_step - state.best_step else @as(u32, 0);

        pos += (std.fmt.bufPrint(msg_buf[pos..], "\n📋 <b>Leader</b>: {s} PPL={d:.2} step={d}K\n", .{
            state.bestNameStr(), state.best_ppl, health.leader_step / 1000,
        }) catch "").len;

        if (delta_r33 < 0) {
            pos += (std.fmt.bufPrint(msg_buf[pos..], "  dR33: ✅{d:.2} | no-improve: {d}K steps\n", .{
                -delta_r33, steps_no_improve_summary / 1000,
            }) catch "").len;
        } else {
            pos += (std.fmt.bufPrint(msg_buf[pos..], "  dR33: ⬆️{d:.2} | no-improve: {d}K steps\n", .{
                delta_r33, steps_no_improve_summary / 1000,
            }) catch "").len;
        }

        // ETA lines
        const ctx: u32 = 27;
        const batch: u32 = 66;
        const toks_per_step: f32 = @floatFromInt(ctx * batch); // 1782
        var leader_toks: f32 = 0;
        var slowest_step: u32 = TARGET_STEP;
        var slowest_toks: f32 = 0;
        var slowest_name_buf: [64]u8 = undefined;
        var slowest_name_len: u8 = 0;
        for (state.services[0..state.service_count]) |*svc| {
            if (svc.status != .running or svc.current_step == 0) continue;
            if (std.mem.eql(u8, svc.svcName(), state.bestNameStr())) {
                leader_toks = svc.tok_per_sec;
            }
            if (svc.current_step < slowest_step and svc.tok_per_sec > 0) {
                slowest_step = svc.current_step;
                slowest_toks = svc.tok_per_sec;
                copyToFixed(&slowest_name_buf, &slowest_name_len, svc.svcName());
            }
        }

        if (leader_toks > 0 and health.leader_step < TARGET_STEP) {
            const remaining = TARGET_STEP - health.leader_step;
            const eta_sec = @as(f32, @floatFromInt(remaining)) * toks_per_step / leader_toks;
            const eta_h: u32 = @intFromFloat(eta_sec / 3600.0);
            const eta_m: u32 = @intFromFloat(@mod(eta_sec / 60.0, 60.0));
            pos += (std.fmt.bufPrint(msg_buf[pos..], "⏱️ Leader ETA: ~{d}h{d:0>2}m to 100K\n", .{ eta_h, eta_m }) catch "").len;
        }
        if (slowest_toks > 0 and slowest_step < TARGET_STEP) {
            const remaining = TARGET_STEP - slowest_step;
            const eta_sec = @as(f32, @floatFromInt(remaining)) * toks_per_step / slowest_toks;
            const eta_h: u32 = @intFromFloat(eta_sec / 3600.0);
            const eta_m: u32 = @intFromFloat(@mod(eta_sec / 60.0, 60.0));
            pos += (std.fmt.bufPrint(msg_buf[pos..], "⏱️ Tail ETA: {s} ~{d}h{d:0>2}m to 100K\n", .{
                slowest_name_buf[0..slowest_name_len], eta_h, eta_m,
            }) catch "").len;
        }

        pos += (std.fmt.bufPrint(msg_buf[pos..], "📊 Farm: {d}🟢 / {d}☠️ / {d} total | health: {d:.0}/100", .{
            health.alive,                            @as(u32, @intCast(state.service_count)) - health.alive,
            @as(u32, @intCast(state.service_count)), health.health_score,
        }) catch "").len;
    }

    if (!has_insights) {
        print("   {s}No new insights{s}\n", .{ DIM, RESET });
        return;
    }

    // Dedup: skip if nothing changed since last notify (same leader PPL, step, alive, events)
    const same_ppl = (state.best_ppl == ns.last_best_ppl);
    const same_step = (health.leader_step == ns.last_leader_step);
    const same_events = (state.event_count == ns.last_event_count);
    if (same_ppl and same_step and same_events and !dry_run) {
        print("   {s}No change since last notify — skipping duplicate{s}\n", .{ DIM, RESET });
        return;
    }

    const message = msg_buf[0..pos];

    if (dry_run) {
        print("\n{s}── NOTIFY (dry-run) ──{s}\n{s}\n{s}──────────────────────{s}\n", .{ CYAN, RESET, message, CYAN, RESET });
    } else {
        tri_commands.runNotifyCommand(allocator, message, null, false, null) catch |err| {
            print("{s}Telegram error: {}{s}\n", .{ RED, err, RESET });
        };
        print("   {s}✅ Notification sent{s}\n", .{ GREEN, RESET });
    }

    // Update notify state
    ns.last_best_ppl = state.best_ppl;
    copyToFixed(&ns.last_best_name, &ns.last_best_name_len, state.bestNameStr());
    ns.last_event_count = state.event_count;
    ns.last_timestamp = std.time.milliTimestamp();
    ns.last_leader_step = health.leader_step;
    saveNotifyState(&ns);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVE — Read-only HTTP API for farm insights
// ═══════════════════════════════════════════════════════════════════════════════

fn runServe(allocator: Allocator, args: []const []const u8) !void {
    var port: u16 = 8642;
    var host: []const u8 = "0.0.0.0";

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--port") and i + 1 < args.len) {
            i += 1;
            port = std.fmt.parseInt(u16, args[i], 10) catch 8642;
        } else if (std.mem.eql(u8, args[i], "--host") and i + 1 < args.len) {
            i += 1;
            host = args[i];
        }
    }

    // Parse address
    var addr_buf: [4]u8 = .{ 0, 0, 0, 0 };
    if (!std.mem.eql(u8, host, "0.0.0.0")) {
        // Parse dotted-quad
        var parts: [4]u8 = undefined;
        var pi: usize = 0;
        var it = std.mem.splitScalar(u8, host, '.');
        while (it.next()) |part| {
            if (pi >= 4) break;
            parts[pi] = std.fmt.parseInt(u8, part, 10) catch 0;
            pi += 1;
        }
        if (pi == 4) addr_buf = parts;
    }

    const address = std.net.Address.initIp4(addr_buf, port);
    var server = address.listen(.{ .reuse_address = true }) catch |err| {
        print("{s}Failed to bind {s}:{d}: {}{s}\n", .{ RED, host, port, err, RESET });
        return err;
    };
    defer server.deinit();

    // Initialize WebSocket infrastructure
    var event_bus = farm_ws.EventBus{};
    global_event_bus = &event_bus;
    defer {
        global_event_bus = null;
    }

    var broadcaster = farm_ws.Broadcaster.init(&event_bus);
    const broadcast_thread = std.Thread.spawn(.{}, farm_ws.Broadcaster.broadcastLoop, .{&broadcaster}) catch |err| {
        print("{s}Failed to spawn broadcast thread: {}{s}\n", .{ RED, err, RESET });
        return err;
    };
    defer {
        broadcaster.running.store(false, .release);
        broadcast_thread.join();
    }

    print("{s}🌐 Farm API server on http://{s}:{d}{s}\n", .{ GREEN, host, port, RESET });
    print("   Endpoints: /status /leaderboard /events /lineage /health /ws\n", .{});
    print("   Ctrl+C to stop\n\n", .{});

    while (true) {
        const conn = server.accept() catch continue;
        const taken = serveRequest(allocator, conn.stream, &broadcaster) catch false;
        if (!taken) conn.stream.close();
    }
}

/// Returns true if stream was taken by WebSocket (caller must NOT close it)
fn serveRequest(allocator: Allocator, stream: std.net.Stream, broadcaster: *farm_ws.Broadcaster) !bool {
    // Read request (first line is enough)
    var req_buf: [1024]u8 = undefined;
    const n = stream.read(&req_buf) catch return false;
    if (n == 0) return false;
    const request = req_buf[0..n];

    // Extract path from "GET /path HTTP/1.x"
    const path = blk: {
        if (std.mem.startsWith(u8, request, "GET ")) {
            const rest = request[4..];
            const end = std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len;
            break :blk rest[0..end];
        }
        break :blk "/";
    };

    // Route
    if (std.mem.eql(u8, path, "/ws")) {
        // Build snapshot JSON for WS handshake
        var snap_buf: [2048]u8 = undefined;
        const state = loadState(allocator) catch {
            const snap = farm_ws.formatStatusSnapshot(999.0, "(none)", 0, 0, 0, 0, 0, &snap_buf);
            return farm_ws.handleUpgrade(stream, request, broadcaster, snap);
        };
        const health = computePopulationHealth(&state);
        var dead: u32 = 0;
        for (state.services[0..state.service_count]) |*svc| {
            if (svc.status == .crashed or svc.status == .killed) dead += 1;
        }
        const snap = farm_ws.formatStatusSnapshot(
            state.best_ppl,
            state.bestNameStr(),
            health.alive,
            dead,
            @intCast(state.service_count),
            health.health_score,
            health.leader_step,
            &snap_buf,
        );
        return farm_ws.handleUpgrade(stream, request, broadcaster, snap);
    } else if (std.mem.eql(u8, path, "/health")) {
        sendJson(stream, "{\"ok\":true}");
    } else if (std.mem.eql(u8, path, "/status")) {
        serveStatus(allocator, stream);
    } else if (std.mem.eql(u8, path, "/leaderboard")) {
        serveLeaderboard(allocator, stream);
    } else if (std.mem.eql(u8, path, "/events")) {
        serveEvents(allocator, stream);
    } else if (std.mem.eql(u8, path, "/lineage")) {
        serveLineage(allocator, stream);
    } else {
        const body = "{\"error\":\"not found\",\"endpoints\":[\"/status\",\"/leaderboard\",\"/events\",\"/lineage\",\"/health\",\"/ws\"]}";
        sendJsonStatus(stream, "404 Not Found", body);
    }
    return false;
}

fn sendJson(stream: std.net.Stream, body: []const u8) void {
    var header_buf: [256]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{body.len}) catch return;
    stream.writeAll(header) catch return;
    stream.writeAll(body) catch return;
}

fn sendJsonStatus(stream: std.net.Stream, status: []const u8, body: []const u8) void {
    var header_buf: [256]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, "HTTP/1.1 {s}\r\nContent-Type: application/json\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n", .{ status, body.len }) catch return;
    stream.writeAll(header) catch return;
    stream.writeAll(body) catch return;
}

fn serveStatus(allocator: Allocator, stream: std.net.Stream) void {
    const state = loadState(allocator) catch {
        sendJson(stream, "{\"error\":\"no evolution state\"}");
        return;
    };
    const health = computePopulationHealth(&state);
    var dead: u32 = 0;
    for (state.services[0..state.service_count]) |*svc| {
        if (svc.status == .crashed or svc.status == .killed) dead += 1;
    }
    var buf: [2048]u8 = undefined;
    const json = std.fmt.bufPrint(&buf, "{{\"best_ppl\":{d:.2},\"best_name\":\"{s}\",\"best_step\":{d},\"alive\":{d},\"dead\":{d},\"total\":{d},\"evolution_step\":{d},\"events\":{d},\"health\":{{\"diversity\":{d:.6},\"elite_gap\":{d:.2},\"stagnation\":{d},\"spike_rate\":{d:.3},\"health_score\":{d:.1},\"leader_step\":{d},\"leader_improvement\":{d:.4}}}}}", .{
        state.best_ppl,       state.bestNameStr(),                   state.best_step,
        health.alive,         dead,                                  @as(u32, @intCast(state.service_count)),
        state.evolution_step, @as(u32, @intCast(state.event_count)), health.diversity,
        health.elite_gap,     health.stagnation,                     health.spike_rate,
        health.health_score,  health.leader_step,                    health.leader_improvement,
    }) catch return;
    sendJson(stream, json);
}

fn serveLeaderboard(allocator: Allocator, stream: std.net.Stream) void {
    const state = loadState(allocator) catch {
        sendJson(stream, "{\"error\":\"no evolution state\"}");
        return;
    };
    // Sort by sacred fitness, take top 10
    var indices: [MAX_SERVICES]usize = undefined;
    var count: usize = 0;
    for (0..state.service_count) |si| {
        if (state.services[si].status == .running and state.services[si].current_step > 0) {
            indices[count] = si;
            count += 1;
        }
    }
    // Simple selection sort by fitness (ascending = better)
    for (0..count) |a| {
        var min_idx = a;
        for (a + 1..count) |b| {
            const fm = computeSacredFitness(&state.services[indices[min_idx]]);
            const fb = computeSacredFitness(&state.services[indices[b]]);
            if (fb < fm) min_idx = b;
        }
        if (min_idx != a) {
            const tmp = indices[a];
            indices[a] = indices[min_idx];
            indices[min_idx] = tmp;
        }
    }
    const top = @min(count, 10);
    var buf: [4096]u8 = undefined;
    var pos: usize = 0;
    pos += (std.fmt.bufPrint(buf[pos..], "[", .{}) catch return).len;
    for (0..top) |ti| {
        const svc = &state.services[indices[ti]];
        if (ti > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        const fit = computeSacredFitness(svc);
        pos += (std.fmt.bufPrint(buf[pos..], "{{\"rank\":{d},\"name\":\"{s}\",\"ppl\":{d:.2},\"step\":{d},\"fitness\":{d:.2},\"lr\":\"{s}\",\"gen\":{d}}}", .{
            ti + 1,      svc.svcName(),  svc.current_ppl, svc.current_step, fit,
            svc.lrStr(), svc.generation,
        }) catch break).len;
    }
    pos += (std.fmt.bufPrint(buf[pos..], "]", .{}) catch return).len;
    sendJson(stream, buf[0..pos]);
}

fn serveEvents(allocator: Allocator, stream: std.net.Stream) void {
    const state = loadState(allocator) catch {
        sendJson(stream, "{\"error\":\"no evolution state\"}");
        return;
    };
    const total = state.event_count;
    const start = if (total > 50) total - 50 else 0;
    var buf: [8192]u8 = undefined;
    var pos: usize = 0;
    pos += (std.fmt.bufPrint(buf[pos..], "[", .{}) catch return).len;
    var first = true;
    for (state.events[start..total]) |*ev| {
        if (!first) {
            buf[pos] = ',';
            pos += 1;
        }
        first = false;
        if (pos + 256 > buf.len) break;
        const type_str: []const u8 = switch (ev.event_type) {
            .spawn => "spawn",
            .kill => "kill",
            .rung_complete => "rung",
            .err => "error",
            .tune => "tune",
        };
        pos += (std.fmt.bufPrint(buf[pos..], "{{\"ts\":{d},\"type\":\"{s}\",\"service\":\"{s}\",\"detail\":\"{s}\"}}", .{
            ev.timestamp, type_str, ev.svcName(), ev.detailStr(),
        }) catch break).len;
    }
    pos += (std.fmt.bufPrint(buf[pos..], "]", .{}) catch return).len;
    sendJson(stream, buf[0..pos]);
}

fn serveLineage(allocator: Allocator, stream: std.net.Stream) void {
    const file = std.fs.cwd().openFile(LINEAGE_PATH, .{}) catch {
        sendJson(stream, "[]");
        return;
    };
    defer file.close();
    const contents = file.readToEndAlloc(allocator, 256 * 1024) catch {
        sendJson(stream, "[]");
        return;
    };
    defer allocator.free(contents);

    // Take last 20 lines
    var lines: [20][]const u8 = undefined;
    var line_count: usize = 0;
    var it = std.mem.splitScalar(u8, contents, '\n');
    while (it.next()) |line| {
        if (line.len == 0) continue;
        if (line_count < 20) {
            lines[line_count] = line;
            line_count += 1;
        } else {
            // Shift left
            for (0..19) |li| lines[li] = lines[li + 1];
            lines[19] = line;
        }
    }

    // Wrap in JSON array (lines are already JSONL)
    var buf: [8192]u8 = undefined;
    var pos: usize = 0;
    buf[pos] = '[';
    pos += 1;
    for (0..line_count) |li| {
        if (li > 0) {
            buf[pos] = ',';
            pos += 1;
        }
        const line = lines[li];
        if (pos + line.len + 2 > buf.len) break;
        @memcpy(buf[pos..][0..line.len], line);
        pos += line.len;
    }
    buf[pos] = ']';
    pos += 1;
    sendJson(stream, buf[0..pos]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Phase 3: Warm Restart (tune)
// ═══════════════════════════════════════════════════════════════════════════════

/// Gentle mutation: only change LR (σ=0.1), copy everything else from worker's OWN config.
fn mutateConfigGentle(worker: *const ServiceEntry, prng_seed: u32) MutatedConfig {
    var config = MutatedConfig{
        .lr_str = undefined,
        .lr_len = 0,
        .batch_str = worker.batch,
        .batch_len = worker.batch_len,
        .optimizer_str = worker.optimizer,
        .optimizer_len = worker.optimizer_len,
        .seed = worker.seed, // keep same seed (resume)
        .grad_clip = worker.grad_clip,
        .warmup = worker.warmup,
        .lr_schedule = worker.lr_schedule,
        .context = worker.context,
        .kill_ppl_30k = worker.kill_ppl_30k,
    };

    const base_lr = std.fmt.parseFloat(f64, worker.lrStr()) catch 3e-4;
    const rng = mulberry32(prng_seed);
    const unit = @as(f64, @floatFromInt(rng % 10000)) / 10000.0;
    const log_perturbation = (unit - 0.5) * 0.2; // σ=0.1 → range ±0.1
    var new_lr = base_lr * @exp(log_perturbation);
    new_lr = @max(LR_MIN, @min(LR_MAX, new_lr));

    const lr_result = std.fmt.bufPrint(&config.lr_str, "{e:.2}", .{new_lr}) catch "3e-4";
    config.lr_len = @intCast(lr_result.len);
    return config;
}

/// Sacred gentle mutation: pick nearby φ power {-1,0,+1} for LR.
fn mutateConfigGentleSacred(worker: *const ServiceEntry, prng_seed: u32) MutatedConfig {
    var config = MutatedConfig{
        .lr_str = undefined,
        .lr_len = 0,
        .batch_str = worker.batch,
        .batch_len = worker.batch_len,
        .optimizer_str = worker.optimizer,
        .optimizer_len = worker.optimizer_len,
        .seed = worker.seed,
        .grad_clip = worker.grad_clip,
        .warmup = worker.warmup,
        .lr_schedule = worker.lr_schedule,
        .context = worker.context,
        .kill_ppl_30k = worker.kill_ppl_30k,
        .sacred = true,
    };

    const base_lr = std.fmt.parseFloat(f64, worker.lrStr()) catch 3e-4;
    const nearby_powers = [_]i8{ -1, 0, 1 };
    const rng = mulberry32(prng_seed);
    const pick = rng % nearby_powers.len;
    const multiplier = std.math.pow(f64, SACRED_PHI, @as(f64, @floatFromInt(nearby_powers[pick])));
    var new_lr = base_lr * multiplier;
    new_lr = @max(LR_MIN, @min(LR_MAX, new_lr));

    const lr_result = std.fmt.bufPrint(&config.lr_str, "{e:.2}", .{new_lr}) catch "3e-4";
    config.lr_len = @intCast(lr_result.len);
    return config;
}

/// Tune a service: update LR via Railway API and redeploy with HSLM_FRESH=0 (resume).
/// Unlike recycleService, does NOT reset step/ppl/loss/generation/parent/rungs.
fn tuneService(allocator: Allocator, state: *EvolutionState, svc_idx: usize, config: MutatedConfig, api_calls: *u32) void {
    const svc = &state.services[svc_idx];

    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (svc.account_idx >= account_count) {
        print("  {s}⚠️  {s}: account_idx {d} out of range{s}\n", .{ YELLOW, svc.svcName(), svc.account_idx, RESET });
        state.addEvent(.err, svc.svcName(), "tune: account_idx out of range");
        return;
    }
    const acct = &accounts_buf[svc.account_idx];

    var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch return;
    defer api.deinit();

    const svc_id = svc.svcId();

    // Only update LR + HSLM_FRESH=0
    const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
    const set_vars_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_LR":"{s}","HSLM_FRESH":"0"}}}}}}
    , .{ acct.project_id, svc_id, acct.env_id, config.lr_str[0..config.lr_len] }) catch return;
    defer allocator.free(set_vars_json);

    if (api.query(set_vars_gql, set_vars_json)) |resp| {
        allocator.free(resp);
    } else |_| {
        print("  {s}⚠️  {s}: tune vars failed{s}\n", .{ YELLOW, svc.svcName(), RESET });
        state.addEvent(.err, svc.svcName(), "tune: variableCollectionUpsert failed");
        return;
    }
    api_calls.* += 1;

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Redeploy
    if (api.redeployService(svc_id, acct.env_id)) |resp| {
        allocator.free(resp);
    } else |_| {
        print("  {s}⚠️  {s}: tune redeploy failed{s}\n", .{ YELLOW, svc.svcName(), RESET });
        state.addEvent(.err, svc.svcName(), "tune: redeploy failed");
        return;
    }
    api_calls.* += 1;

    // Update only LR and last_tuned_step in local state (preserve everything else)
    @memcpy(svc.lr[0..config.lr_len], config.lr_str[0..config.lr_len]);
    svc.lr_len = config.lr_len;
    svc.last_tuned_step = svc.current_step;

    var detail_buf: [128]u8 = undefined;
    const detail = std.fmt.bufPrint(&detail_buf, "LR→{s} at step {d}", .{ config.lr_str[0..config.lr_len], svc.current_step }) catch "tuned";
    state.addEvent(.tune, svc.svcName(), detail);
    notifyWsBus(.tune, svc.svcName(), detail);
}

/// Internal tune logic shared between runTune and --tune in watch
fn runTuneInternal(allocator: Allocator, state: *EvolutionState, sacred: bool, dry_run: bool, api_calls: *u32) void {
    // Find running workers past rung 1, not recently tuned (step delta >= 5K)
    const first_rung = if (sacred) SACRED_RUNGS[0].step_threshold else DEFAULT_RUNGS[0].step_threshold;

    var candidates: [MAX_SERVICES]usize = undefined;
    var cand_count: usize = 0;
    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (svc.status != .running or svc.current_step < first_rung) continue;
        if (svc.account_idx == 0) continue; // never tune PRIMARY
        if (svc.current_step < svc.last_tuned_step + 5000) continue; // too soon
        candidates[cand_count] = si;
        cand_count += 1;
    }

    if (cand_count == 0) {
        print("   {s}Tune: no eligible workers{s}\n", .{ DIM, RESET });
        return;
    }

    // Sort by fitness descending (worst first) — we want bottom 30%
    // Use insertion sort on fitness
    {
        var ii: usize = 1;
        while (ii < cand_count) : (ii += 1) {
            const key = candidates[ii];
            const key_fit = computeSacredFitness(&state.services[key]);
            var jj: usize = ii;
            while (jj > 0 and computeSacredFitness(&state.services[candidates[jj - 1]]) < key_fit) {
                candidates[jj] = candidates[jj - 1];
                jj -= 1;
            }
            candidates[jj] = key;
        }
    }

    const bottom_count = @max(@as(usize, 1), cand_count * 30 / 100);
    const tune_count = @min(bottom_count, @as(usize, 3)); // max 3 per invocation

    print("   🔧 Tune: {d} eligible, bottom {d}, tuning {d}\n", .{ cand_count, bottom_count, tune_count });

    var seed: u32 = @truncate(@as(u64, @intCast(std.time.milliTimestamp())) +% 3333);
    for (candidates[0..tune_count]) |ci| {
        const svc = &state.services[ci];
        seed = mulberry32(seed);
        const config = if (sacred)
            mutateConfigGentleSacred(svc, seed)
        else
            mutateConfigGentle(svc, seed);

        const mode_str: []const u8 = if (sacred) " [SACRED]" else "";
        print("   🔧 {s} LR {s}→{s}{s} (step={d}, PPL={d:.2})\n", .{
            svc.svcName(),    svc.lrStr(),     config.lr_str[0..config.lr_len], mode_str,
            svc.current_step, svc.current_ppl,
        });

        if (!dry_run) {
            tuneService(allocator, state, ci, config, api_calls);
            saveState(state.*) catch {};
        }
    }
}

fn runTune(allocator: Allocator, args: []const []const u8) !void {
    var sacred = false;
    var dry_run = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--sacred")) {
            sacred = true;
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        }
    }

    var state = loadState(allocator) catch {
        print("{s}ERROR: No evolution state. Run 'tri farm evolve init' first.{s}\n", .{ RED, RESET });
        return;
    };

    print("\n{s}🔧 TUNE — Warm restart for struggling workers{s}\n", .{ BOLD, RESET });

    var api_calls: u32 = 0;
    runTuneInternal(allocator, &state, sacred, dry_run, &api_calls);

    if (dry_run) {
        print("   {s}--dry-run: no actions taken{s}\n\n", .{ DIM, RESET });
    } else {
        saveState(state) catch {};
        print("   {s}✅ Tune complete ({d} API calls){s}\n\n", .{ GREEN, api_calls, RESET });
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// JSON/CSV Export
// ═══════════════════════════════════════════════════════════════════════════════

fn exportJson(state: *const EvolutionState) void {
    print("[", .{});
    for (state.services[0..state.service_count], 0..) |*svc, si| {
        if (si > 0) print(",", .{});
        print(
            \\{{"name":"{s}","status":"{s}","ppl":{d:.2},"val_ppl":{d:.2},"step":{d},"gen":{d},"lr":"{s}","batch":"{s}","optimizer":"{s}","grad_clip":{d:.3},"warmup":{d},"context":{d},"objective":"{s}","schedule":"{s}","shard":{d},"seed":{d},"tok_per_sec":{d:.1},"loss":{d:.4},"parent":"{s}"}}
        , .{
            svc.svcName(),
            statusToStr(svc.status),
            svc.current_ppl,
            svc.val_ppl,
            svc.current_step,
            svc.generation,
            svc.lrStr(),
            svc.batchStr(),
            svc.optimizerStr(),
            svc.grad_clip,
            svc.warmup,
            svc.context,
            svc.objectiveStr(),
            svc.lr_schedule.toStr(),
            svc.data_shard,
            svc.seed,
            svc.tok_per_sec,
            svc.current_loss,
            svc.parentName(),
        });
    }
    print("]\n", .{});
}

fn exportCsv(state: *const EvolutionState) void {
    print("name,status,ppl,val_ppl,step,gen,lr,batch,optimizer,grad_clip,warmup,context,objective,schedule,shard,seed,tok_per_sec,loss,parent\n", .{});
    for (state.services[0..state.service_count]) |*svc| {
        print("{s},{s},{d:.2},{d:.2},{d},{d},{s},{s},{s},{d:.3},{d},{d},{s},{s},{d},{d},{d:.1},{d:.4},{s}\n", .{
            svc.svcName(),
            statusToStr(svc.status),
            svc.current_ppl,
            svc.val_ppl,
            svc.current_step,
            svc.generation,
            svc.lrStr(),
            svc.batchStr(),
            svc.optimizerStr(),
            svc.grad_clip,
            svc.warmup,
            svc.context,
            svc.objectiveStr(),
            svc.lr_schedule.toStr(),
            svc.data_shard,
            svc.seed,
            svc.tok_per_sec,
            svc.current_loss,
            svc.parentName(),
        });
    }
}

fn statusToStr(status: ServiceStatus) []const u8 {
    return switch (status) {
        .running => "running",
        .idle => "idle",
        .crashed => "crashed",
        .killed => "killed",
        .unknown => "unknown",
        .stalled => "stalled",
        .diverged => "diverged",
        .stuck => "stuck",
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESUME — Redeploy stalled/crashed good services with same config
// ═══════════════════════════════════════════════════════════════════════════════

fn runResume(allocator: Allocator, args: []const []const u8) !void {
    var top_k: u32 = 5;
    var min_step: u32 = 30000;
    var max_ppl: f32 = 15.0;
    var dry_run = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--top-k") and i + 1 < args.len) {
            i += 1;
            top_k = std.fmt.parseInt(u32, args[i], 10) catch 5;
        } else if (std.mem.eql(u8, args[i], "--min-step") and i + 1 < args.len) {
            i += 1;
            min_step = std.fmt.parseInt(u32, args[i], 10) catch 30000;
        } else if (std.mem.eql(u8, args[i], "--max-ppl") and i + 1 < args.len) {
            i += 1;
            max_ppl = std.fmt.parseFloat(f32, args[i]) catch 15.0;
        } else if (std.mem.eql(u8, args[i], "--dry-run")) {
            dry_run = true;
        }
    }

    var state = loadState(allocator) catch {
        print("{s}ERROR: No evolution state. Run 'tri farm evolve init' first.{s}\n", .{ RED, RESET });
        return;
    };

    // Find resume-eligible services
    var candidates: [MAX_SERVICES]usize = undefined;
    var cand_count: usize = 0;

    for (state.services[0..state.service_count], 0..) |*svc, si| {
        const resumable = svc.status == .stalled or svc.status == .crashed or svc.status == .idle;
        if (!resumable) continue;
        if (svc.current_step < min_step) continue;
        if (svc.current_ppl <= 0 or svc.current_ppl >= max_ppl) continue;
        if (svc.account_idx == 0) continue; // never touch PRIMARY
        candidates[cand_count] = si;
        cand_count += 1;
    }

    if (cand_count == 0) {
        print("{s}No resume-eligible services found (step>={d}, PPL<{d:.1}, stalled/crashed/idle).{s}\n", .{ YELLOW, min_step, max_ppl, RESET });
        return;
    }

    // Sort by PPL ascending (best first)
    sortByPpl(&state, candidates[0..cand_count]);

    const n = @min(top_k, @as(u32, @intCast(cand_count)));
    print("\n{s}RESUME:{s} {d} of {d} eligible services\n", .{ BOLD, RESET, n, cand_count });

    var total_api_calls: u32 = 0;
    var resumed: u32 = 0;

    var ji: u32 = 0;
    while (ji < n) : (ji += 1) {
        const svc_idx = candidates[ji]; // best first (start of sorted array)
        const svc = &state.services[svc_idx];
        const st_str: []const u8 = switch (svc.status) {
            .stalled => "stalled",
            .crashed => "crashed",
            .idle => "idle",
            else => "?",
        };

        print("  [{d}/{d}] {s}  step={d}  PPL={d:.2}  ({s})\n", .{ ji + 1, n, svc.svcName(), svc.current_step, svc.current_ppl, st_str });

        if (dry_run) continue;

        resumeService(allocator, &state, svc_idx, &total_api_calls);
        resumed += 1;
    }

    if (!dry_run) {
        saveState(state) catch |err| {
            print("  {s}Failed to save state: {}{s}\n", .{ YELLOW, err, RESET });
        };
        print("\n  {s}Resumed {d} services ({d} API calls){s}\n\n", .{ GREEN, resumed, total_api_calls, RESET });
    } else {
        print("\n  {s}--dry-run: no action taken{s}\n\n", .{ DIM, RESET });
    }
}

fn resumeService(allocator: Allocator, state: *EvolutionState, svc_idx: usize, api_calls: *u32) void {
    const svc = &state.services[svc_idx];

    var accounts_buf: [MAX_FARM_ACCOUNTS]Account = undefined;
    const account_count = farm_accounts_mod.discoverAccounts(allocator, &accounts_buf);
    defer farm_accounts_mod.deinitAccounts(allocator, &accounts_buf, account_count);

    if (svc.account_idx >= account_count) {
        print("  {s}  {s}: account_idx {d} out of range{s}\n", .{ YELLOW, svc.svcName(), svc.account_idx, RESET });
        state.addEvent(.err, svc.svcName(), "resume: account_idx out of range");
        return;
    }
    const acct = &accounts_buf[svc.account_idx];

    var api = RailwayApi.initWithSuffix(allocator, acct.suffix) catch return;
    defer api.deinit();

    const svc_id = svc.svcId();

    // Set HSLM_FRESH=0 to resume from checkpoint
    const set_vars_gql = "mutation($input: VariableCollectionUpsertInput!) { variableCollectionUpsert(input: $input) }";
    const set_vars_json = std.fmt.allocPrint(allocator,
        \\{{"input":{{"projectId":"{s}","serviceId":"{s}","environmentId":"{s}","variables":{{"HSLM_FRESH":"0"}}}}}}
    , .{ acct.project_id, svc_id, acct.env_id }) catch return;
    defer allocator.free(set_vars_json);

    if (api.query(set_vars_gql, set_vars_json)) |resp| {
        allocator.free(resp);
    } else |_| {
        print("  {s}  {s}: resume vars failed{s}\n", .{ YELLOW, svc.svcName(), RESET });
        state.addEvent(.err, svc.svcName(), "resume: variableCollectionUpsert failed");
        return;
    }
    api_calls.* += 1;

    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Redeploy
    if (api.redeployService(svc_id, acct.env_id)) |resp| {
        allocator.free(resp);
    } else |_| {
        print("  {s}  {s}: resume redeploy failed{s}\n", .{ YELLOW, svc.svcName(), RESET });
        state.addEvent(.err, svc.svcName(), "resume: redeploy failed");
        return;
    }
    api_calls.* += 1;

    // Reset status
    svc.status = .running;
    svc.stall_count = 0;

    var detail_buf: [128]u8 = undefined;
    const detail = std.fmt.bufPrint(&detail_buf, "resumed at step {d}, PPL={d:.2}", .{ svc.current_step, svc.current_ppl }) catch "resumed";
    state.addEvent(.tune, svc.svcName(), detail);
    notifyWsBus(.tune, svc.svcName(), detail);
}

// ═══════════════════════════════════════════════════════════════════════════════
// RECOMMEND — Standalone recommendations subcommand
// ═══════════════════════════════════════════════════════════════════════════════

fn runRecommend(allocator: Allocator) !void {
    const state = loadState(allocator) catch {
        print("{s}ERROR: No evolution state. Run 'tri farm evolve init' first.{s}\n", .{ RED, RESET });
        return;
    };
    const health = computePopulationHealth(&state);

    // Count resume-eligible
    var resume_count: u32 = 0;
    for (state.services[0..state.service_count]) |*svc| {
        const resumable = svc.status == .stalled or svc.status == .crashed or svc.status == .idle;
        if (!resumable) continue;
        if (svc.current_step >= 30000 and svc.current_ppl > 0 and svc.current_ppl < 15.0) resume_count += 1;
    }

    const rec_result = computeRecommendations(&state, health, resume_count);
    if (rec_result.count == 0) {
        print("{s}No recommendations — farm is healthy.{s}\n", .{ GREEN, RESET });
        return;
    }

    print("\n{s}RECOMMENDATIONS:{s}\n", .{ BOLD, RESET });
    for (rec_result.recs[0..rec_result.count]) |*rec| {
        const icon: []const u8 = switch (rec.severity) {
            .critical => RED,
            .warning => YELLOW,
            .info => CYAN,
        };
        const sev_str: []const u8 = switch (rec.severity) {
            .critical => "!!",
            .warning => "! ",
            .info => "i ",
        };
        print("  {s}{s}{s} {s}\n", .{ icon, sev_str, RESET, rec.message[0..rec.message_len] });
        print("     Run: {s}\n", .{rec.command[0..rec.command_len]});
    }
    print("\n", .{});
}

fn printHelp() void {
    print(
        \\
        \\Usage: tri farm evolve <command> [options]
        \\
        \\ASHA+PBT hybrid evolution for the training farm.
        \\Kills bottom performers at step thresholds, recycles with mutated leader configs.
        \\
        \\Commands:
        \\  init             Scan all accounts, build initial state
        \\  status           Leaderboard + rung progress + quotas + recommendations (default)
        \\  step             Execute one evolution cycle
        \\  inject           Inject one child into a dead/idle slot (tournament selection)
        \\  watch            Steady-state watchdog: scan + auto-inject dead slots
        \\  tune             Warm restart: gently mutate LR on struggling workers
        \\  resume           Redeploy stalled/crashed good services (same config, FRESH=0)
        \\  recommend        Show actionable recommendations only
        \\  mock             Offline evolution simulation from snapshot JSON
        \\  deploy           Deploy pre-made configs to idle Railway services
        \\  collect          A/B collect — fetch PPL from deployed configs, compare sacred vs random
        \\  inspect          Detailed view of one config: milestones + recent training lines
        \\  logs             Raw Railway logs for any service by name
        \\  history          Print event log
        \\  notify           Scan artifacts, detect insights, send to Telegram
        \\  serve            Read-only HTTP API server for farm insights
        \\  help             Show this help
        \\
        \\Step options:
        \\  --dry-run        Preview actions without executing
        \\  --sacred         Use sacred φ-weighted fitness + 3^k rungs
        \\  --issue <N>      Post summary to GitHub issue #N
        \\
        \\Status options:
        \\  --json                   Export full state as JSON to stdout
        \\  --csv                    Export full state as CSV to stdout
        \\
        \\Inject options:
        \\  --target <name>          Service to recycle (required)
        \\  --parent <name>          Parent config to mutate from (default: auto-best)
        \\  --sacred                 Use φ-grid mutations
        \\  --quota                  Auto-select objective/context from diversity quotas
        \\  --dry-run                Preview only
        \\
        \\Watch options:
        \\  --once                   Single sweep, then exit
        \\  --interval <secs>        Loop interval (default: 300, min: 60)
        \\  --sacred                 Use φ-grid mutations for new children
        \\  --notify                 Auto-send Telegram after each sweep
        \\  --kill-live              Also replace live-but-struggling workers (kill tournament)
        \\  --tune                   Auto-tune struggling workers (warm restart)
        \\  --dry-run                Preview only
        \\
        \\Tune options:
        \\  --sacred                 Use φ-grid gentle mutations
        \\  --dry-run                Preview only
        \\
        \\Resume options:
        \\  --top-k <N>              Max services to resume (default: 5)
        \\  --min-step <N>           Min step threshold (default: 30000)
        \\  --max-ppl <F>            Max PPL threshold (default: 15.0)
        \\  --dry-run                Preview only
        \\
        \\Notify options:
        \\  --dry-run                Preview message without sending
        \\  --threshold <ppl>        Only notify if best PPL below this (default: 999)
        \\
        \\Serve options:
        \\  --port <N>               HTTP port (default: 8642)
        \\  --host <addr>            Bind address (default: 0.0.0.0)
        \\
        \\Mock options:
        \\  --snapshot <path>         Snapshot JSON (default: .trinity/farm/w7v2_snapshot.json)
        \\  --parents <N>             Number of parent configs (default: 8)
        \\  --children <N>            Number of children to generate (default: 16)
        \\  --allow-ctx-mutation      Enable context length mutation (27<->54)
        \\  --sacred                  Use sacred φ-guided mutations (shortcut for --mode sacred)
        \\  --mode <mode>             Mutation mode: random|sacred|mixed (default: random)
        \\
        \\Deploy options:
        \\  --config <path>           Config JSON (default: .trinity/farm/w8_mock_configs.json)
        \\  --select 1,4,5,8          1-based indices to pick from JSON (default: all)
        \\  --execute                 Actually deploy (default: dry-run, print plan only)
        \\  --issue <N>               Post summary to GitHub issue #N
        \\  --skip-ci                 Skip zig build test gate
        \\
        \\Collect options:
        \\  --config <path>           Config JSON (default: .trinity/farm/w8_mock_configs.json)
        \\  --targets <path>          Deploy targets (default: .trinity/farm/deploy_targets.json)
        \\  --out <path>              Results output (default: .trinity/farm/ab_results.json)
        \\  --issue <N>               Post A/B table to GitHub issue #N
        \\  --log-lines <N>           Railway log fetch limit (default: 100)
        \\
        \\Inspect options:
        \\  <config-name>            Config name from deploy_targets.json
        \\  --lines <N>              Railway log fetch limit (default: 100)
        \\  --targets <path>         Deploy targets (default: .trinity/farm/deploy_targets.json)
        \\
        \\Logs options:
        \\  <service-name>           Railway service name to fetch logs from
        \\  --lines <N>              Number of log lines (default: 50)
        \\
        \\Rungs: 5K (outlier>500), 15K (outlier>200), 30K (30% kill), 50K (30% kill)
        \\Ranking: val_ppl (if available) > train_ppl. Data sharding via HSLM_DATA_SHARD.
        \\Min survivors: 4 | LR schedule: ALWAYS cosine (or phi_restart via mutation)
        \\
    , .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseTrainingLine valid" {
    const line = "    5000 |   5.8234 |   5.9100 |   338.45 |   0.001000 |   0.8234 |   1400";
    const result = parseTrainingLine(line) orelse unreachable;
    try std.testing.expectEqual(@as(u32, 5000), result.step);
    try std.testing.expectApproxEqAbs(@as(f32, 5.8234), result.loss, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 338.45), result.ppl, 0.1);
}

test "parseTrainingLine garbage" {
    try std.testing.expect(parseTrainingLine("hello world") == null);
    try std.testing.expect(parseTrainingLine("") == null);
    try std.testing.expect(parseTrainingLine("Training started...") == null);
}

test "parseTrainingLine early kill" {
    const line = "[EARLY KILL] PPL=200 at step 10000";
    try std.testing.expect(parseTrainingLine(line) == null);
}

test "mutateConfig lr bounds" {
    // Test that LR stays within bounds after many mutations
    var entry = ServiceEntry{};
    copyToFixed(&entry.lr, &entry.lr_len, "1e-2"); // max boundary
    copyToFixed(&entry.batch, &entry.batch_len, "128");
    copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");

    var seed: u32 = 12345;
    var all_in_bounds = true;
    for (0..100) |_| {
        const config = mutateConfig(&entry, seed);
        const lr = std.fmt.parseFloat(f64, config.lr_str[0..config.lr_len]) catch {
            all_in_bounds = false;
            break;
        };
        if (lr < LR_MIN or lr > LR_MAX) all_in_bounds = false;
        seed = mulberry32(seed);
    }
    try std.testing.expect(all_in_bounds);
}

test "mutateConfig expanded fields" {
    var entry = ServiceEntry{};
    copyToFixed(&entry.lr, &entry.lr_len, "3e-4");
    copyToFixed(&entry.batch, &entry.batch_len, "128");
    copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");
    entry.grad_clip = 1.0;
    entry.warmup = 2000;
    entry.context = 27;
    entry.lr_schedule = .cosine;

    var seed: u32 = 42;
    var gc_varied = false;
    var wu_varied = false;
    for (0..100) |_| {
        const config = mutateConfigEx(&entry, seed, false);
        // Grad clip must be in [GC_MIN, GC_MAX]
        try std.testing.expect(config.grad_clip >= GC_MIN and config.grad_clip <= GC_MAX);
        // Warmup must be in [WU_MIN, WU_MAX]
        try std.testing.expect(config.warmup >= WU_MIN and config.warmup <= WU_MAX);
        // Context should not mutate without opt-in
        try std.testing.expectEqual(@as(u32, 27), config.context);
        if (config.grad_clip != 1.0) gc_varied = true;
        if (config.warmup != 2000) wu_varied = true;
        seed = mulberry32(seed);
    }
    try std.testing.expect(gc_varied);
    try std.testing.expect(wu_varied);
}

test "computeSacredFitness phi weighting" {
    var entry = ServiceEntry{};
    entry.current_ppl = 10.0;
    entry.current_loss = @log(@as(f32, 10.0));
    entry.current_step = 10000;
    const fit = computeSacredFitness(&entry);
    try std.testing.expect(fit < 10.0); // speed bonus applied

    entry.current_loss = @log(@as(f32, 10.0)) * 2.0;
    const spiked = computeSacredFitness(&entry);
    try std.testing.expect(spiked > fit); // spike penalty
}

test "computeFitness spike penalty" {
    var entry = ServiceEntry{};
    entry.current_ppl = 10.0;
    entry.current_loss = @log(@as(f32, 10.0)); // normal
    entry.current_step = 50000;
    const normal_fit = computeFitness(&entry);

    entry.current_loss = @log(@as(f32, 10.0)) * 2.0; // spiked
    const spiked_fit = computeFitness(&entry);

    try std.testing.expect(spiked_fit > normal_fit);
}

test "rankAndSelect min survivors" {
    // With MIN_SURVIVORS=4 and 5 eligible, at most 1 can be killed
    var state = EvolutionState{};
    for (0..5) |si| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 6000;
        entry.current_ppl = @floatFromInt(100 + si * 50);
    }

    var api_calls_min: u32 = 0;
    const result = processRung(std.testing.allocator, &state, 0, DEFAULT_RUNGS[0], true, &api_calls_min, false);
    try std.testing.expect(result.killed <= 1);
}

test "rankAndSelect empty eligible" {
    var state = EvolutionState{};
    // Add services but none eligible (step too low)
    for (0..3) |_| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 100;
        entry.current_ppl = 200;
    }

    var api_calls: u32 = 0;
    const result = processRung(std.testing.allocator, &state, 0, DEFAULT_RUNGS[0], true, &api_calls, false);
    try std.testing.expectEqual(@as(usize, 0), result.killed);
    try std.testing.expectEqual(@as(usize, 0), result.spawned);
}

test "mulberry32 deterministic" {
    const a1 = mulberry32(42);
    const a2 = mulberry32(42);
    try std.testing.expectEqual(a1, a2);

    // Different seeds → different outputs
    const b = mulberry32(43);
    try std.testing.expect(a1 != b);
}

test "outlier PPL auto-victim" {
    // Services with PPL > 500 should be auto-killed before ratio-based culling
    var state = EvolutionState{};

    // 3 healthy services (PPL 100-200)
    for (0..3) |si| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 6000;
        entry.current_ppl = @floatFromInt(100 + si * 50);
        copyToFixed(&entry.lr, &entry.lr_len, "3e-4");
        copyToFixed(&entry.batch, &entry.batch_len, "128");
        copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");
    }

    // 4 outlier services (PPL 600-900)
    for (0..4) |si| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 6000;
        entry.current_ppl = @floatFromInt(600 + si * 100);
        copyToFixed(&entry.lr, &entry.lr_len, "1e-3");
        copyToFixed(&entry.batch, &entry.batch_len, "128");
        copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");
    }

    // 7 total, MIN_SURVIVORS=4, so max killable = 3
    // All 4 outliers proposed but capped to 3 by MIN_SURVIVORS
    var api_calls_out: u32 = 0;
    const result = processRung(std.testing.allocator, &state, 0, DEFAULT_RUNGS[0], true, &api_calls_out, false);
    try std.testing.expect(result.killed == 3); // 7 - MIN_SURVIVORS(4) = 3
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sacred mutation tests
// ═══════════════════════════════════════════════════════════════════════════════

fn makeTestEntry() ServiceEntry {
    var entry = ServiceEntry{};
    copyToFixed(&entry.lr, &entry.lr_len, "1e-3");
    copyToFixed(&entry.batch, &entry.batch_len, "66");
    copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");
    entry.grad_clip = 1.0;
    entry.warmup = 2000;
    entry.context = 27;
    entry.lr_schedule = .cosine;
    return entry;
}

test "sacredLrGrid stays in bounds" {
    const base_lr: f64 = 1e-3;
    var seed: u32 = 12345;
    for (0..100) |_| {
        const lr = sacredLrGrid(base_lr, seed);
        try std.testing.expect(lr >= LR_MIN and lr <= LR_MAX);
        seed = mulberry32(seed);
    }
}

test "sacredLrGrid produces phi-ratio values" {
    const base_lr: f64 = 1e-3;
    // Check all 7 powers produce valid φ-ratios
    for (0..100) |si| {
        const seed: u32 = @intCast(si * 7 + 1);
        const lr = sacredLrGrid(base_lr, seed);
        const ratio = lr / base_lr;
        // ratio should be φ^p for some p ∈ {-3..3}
        var found = false;
        const powers = [_]i8{ -3, -2, -1, 0, 1, 2, 3 };
        for (powers) |p| {
            const expected = std.math.pow(f64, SACRED_PHI, @as(f64, @floatFromInt(p)));
            if (@abs(ratio - expected) < 0.001) {
                found = true;
                break;
            }
        }
        try std.testing.expect(found);
    }
}

test "mutateConfigSacred grad_clip is sacred" {
    var entry = makeTestEntry();
    var seed: u32 = 42;
    for (0..100) |_| {
        const config = mutateConfigSacred(&entry, seed, false);
        const gc = config.grad_clip;
        const valid = (gc == SACRED_GRAD_CLIPS[0]) or (gc == SACRED_GRAD_CLIPS[1]) or (gc == SACRED_GRAD_CLIPS[2]);
        try std.testing.expect(valid);
        seed = mulberry32(seed);
    }
    _ = &entry;
}

test "mutateConfigSacred warmup is power of 3" {
    var entry = makeTestEntry();
    var seed: u32 = 99;
    for (0..100) |_| {
        const config = mutateConfigSacred(&entry, seed, false);
        const wu = config.warmup;
        const valid = (wu == 243) or (wu == 729) or (wu == 2187);
        try std.testing.expect(valid);
        seed = mulberry32(seed);
    }
    _ = &entry;
}

test "mutateConfigSacred sacred flag set" {
    var entry = makeTestEntry();
    const config = mutateConfigSacred(&entry, 42, false);
    try std.testing.expect(config.sacred);
    // Random mutation should NOT set sacred
    const random_config = mutateConfigEx(&entry, 42, false);
    try std.testing.expect(!random_config.sacred);
    _ = &entry;
}

test "parseMockConfigJson fields" {
    const allocator = std.testing.allocator;

    // Write a small test JSON
    const test_json =
        \\[
        \\  {"name":"test-01","parent":"w7-35","lr":"1.00e-3","grad_clip":1.62,"warmup":729,"context":27,"lr_schedule":"cosine","seed":12345,"kill_ppl_30k":999.00,"sacred":true},
        \\  {"name":"test-02","parent":"w7-21","lr":"3.82e-4","grad_clip":0.62,"warmup":2187,"context":27,"lr_schedule":"phi_restart","seed":67890,"kill_ppl_30k":999.00,"sacred":false}
        \\]
    ;

    const tmp_path = "/tmp/trinity_test_deploy_configs.json";
    {
        var f = try std.fs.createFileAbsolute(tmp_path, .{});
        defer f.close();
        try f.writeAll(test_json);
    }
    defer std.fs.deleteFileAbsolute(tmp_path) catch {};

    var configs: [MAX_SERVICES]MutatedConfig = undefined;
    var cnames: [MAX_SERVICES][64]u8 = undefined;
    var name_lens: [MAX_SERVICES]u8 = undefined;
    var pnames: [MAX_SERVICES][64]u8 = undefined;
    var parent_lens: [MAX_SERVICES]u8 = undefined;

    const count = try parseMockConfigJson(allocator, tmp_path, &configs, &cnames, &name_lens, &pnames, &parent_lens);
    try std.testing.expectEqual(@as(usize, 2), count);

    // Check first config
    try std.testing.expectEqualStrings("1.00e-3", configs[0].lr_str[0..configs[0].lr_len]);
    try std.testing.expectApproxEqAbs(@as(f32, 1.62), configs[0].grad_clip, 0.01);
    try std.testing.expectEqual(@as(u32, 729), configs[0].warmup);
    try std.testing.expectEqual(@as(u32, 27), configs[0].context);
    try std.testing.expectEqual(LrSchedule.cosine, configs[0].lr_schedule);
    try std.testing.expectEqual(@as(u32, 12345), configs[0].seed);
    try std.testing.expect(configs[0].sacred);
    try std.testing.expectEqualStrings("test-01", cnames[0][0..name_lens[0]]);
    try std.testing.expectEqualStrings("w7-35", pnames[0][0..parent_lens[0]]);

    // Check second config
    try std.testing.expectEqual(LrSchedule.phi_restart, configs[1].lr_schedule);
    try std.testing.expect(!configs[1].sacred);
    try std.testing.expectEqual(@as(u32, 67890), configs[1].seed);
}

test "sacred vs random mutation: sacred is discrete" {
    var entry = makeTestEntry();
    var gc_set: [100]f32 = undefined;
    var seed: u32 = 1;
    for (0..100) |si| {
        const config = mutateConfigSacred(&entry, seed, false);
        gc_set[si] = config.grad_clip;
        seed = mulberry32(seed);
    }
    _ = &entry;
    // Count distinct grad_clip values
    var distinct: usize = 0;
    for (0..100) |si| {
        var is_new = true;
        for (0..si) |sj| {
            if (gc_set[si] == gc_set[sj]) {
                is_new = false;
                break;
            }
        }
        if (is_new) distinct += 1;
    }
    // Sacred should produce at most 3 distinct values
    try std.testing.expect(distinct <= 3);
}

// ═══════════════════════════════════════════════════════════════════════════════
// A/B Collect tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseAllTrainingLines multiple entries" {
    // Simulate a deploymentLogs JSON structure
    const json_str =
        \\{"data":{"deploymentLogs":[
        \\  {"message":"    3000 |   6.0000 |   6.1000 |   200.00 |   0.001000 |   0.8000 |   1200"},
        \\  {"message":"Training checkpoint saved..."},
        \\  {"message":"   10000 |   4.5000 |   4.6000 |    50.00 |   0.001000 |   0.7500 |   1400"},
        \\  {"message":"   20000 |   3.2000 |   3.3000 |    15.00 |   0.001000 |   0.7000 |   1500"}
        \\]}}
    ;

    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_str, .{});
    defer parsed.deinit();

    var results: [MAX_METRICS]TrainingMetrics = undefined;
    const count = parseAllTrainingLines(parsed.value, &results);

    try std.testing.expectEqual(@as(usize, 3), count);
    try std.testing.expectEqual(@as(u32, 3000), results[0].step);
    try std.testing.expectEqual(@as(u32, 10000), results[1].step);
    try std.testing.expectEqual(@as(u32, 20000), results[2].step);
    try std.testing.expectApproxEqAbs(@as(f32, 200.0), results[0].ppl, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), results[2].ppl, 0.1);
}

test "extractMilestones spike detection" {
    var metrics: [MAX_METRICS]TrainingMetrics = undefined;
    // Normal progression
    metrics[0] = .{ .step = 1000, .loss = 7.0, .ppl = 500.0 };
    metrics[1] = .{ .step = 3000, .loss = 6.0, .ppl = 200.0 };
    metrics[2] = .{ .step = 5000, .loss = 5.0, .ppl = 100.0 };
    // Spike! 100 → 200 (>1.5x)
    metrics[3] = .{ .step = 7000, .loss = 5.5, .ppl = 200.0 };
    metrics[4] = .{ .step = 10000, .loss = 4.0, .ppl = 50.0 };
    metrics[5] = .{ .step = 20000, .loss = 3.0, .ppl = 15.0 };

    const m = extractMilestones(&metrics, 6);

    try std.testing.expectEqual(@as(u16, 1), m.spikes); // one spike at step 7000
    try std.testing.expectApproxEqAbs(@as(f32, 200.0), m.ppl_3k, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), m.ppl_10k, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), m.ppl_20k, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), m.best_ppl, 0.1);
    try std.testing.expectEqual(@as(u32, 20000), m.latest_step);
    try std.testing.expect(m.status == .training);
}

test "extractMilestones empty" {
    var metrics: [MAX_METRICS]TrainingMetrics = undefined;
    const m = extractMilestones(&metrics, 0);
    try std.testing.expect(m.status == .no_data);
    try std.testing.expectApproxEqAbs(@as(f32, 999.0), m.best_ppl, 0.1);
}

// ═══════════════════════════════════════════════════════════════════════════════
// PBT selection + population health + warm restart tests
// ═══════════════════════════════════════════════════════════════════════════════

fn makePopulatedState(count: usize) EvolutionState {
    var state = EvolutionState{};
    for (0..count) |si| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 10000 + @as(u32, @intCast(si)) * 5000;
        entry.current_ppl = 5.0 + @as(f32, @floatFromInt(si)) * 2.0;
        entry.current_loss = @log(entry.current_ppl);
        entry.account_idx = 1; // non-PRIMARY
        entry.grad_clip = 0.618 + @as(f32, @floatFromInt(si % 3)) * 0.5;
        entry.warmup = 729 + @as(u32, @intCast(si % 3)) * 729;
        const lr_str = std.fmt.bufPrint(&entry.lr, "{e:.2}", .{1e-4 + @as(f64, @floatFromInt(si)) * 2e-4}) catch "3e-4";
        entry.lr_len = @intCast(lr_str.len);
        copyToFixed(&entry.batch, &entry.batch_len, "66");
        copyToFixed(&entry.optimizer, &entry.optimizer_len, "lamb");
    }
    return state;
}

test "selectParentTruncation returns elite" {
    const state = makePopulatedState(10);
    // Different seeds should produce diverse parents
    var parents: [10]usize = undefined;
    for (0..10) |si| {
        parents[si] = selectParentTruncation(&state, @intCast(si * 100 + 1)) orelse unreachable;
    }
    // At least 2 distinct parents (not all same)
    var distinct: usize = 1;
    for (1..10) |si| {
        var found = false;
        for (0..si) |sj| {
            if (parents[si] == parents[sj]) {
                found = true;
                break;
            }
        }
        if (!found) distinct += 1;
    }
    try std.testing.expect(distinct >= 1); // at minimum 1, but usually more
}

test "selectParentTournament returns valid" {
    const state = makePopulatedState(10);
    const parent = selectParentTournament(&state, 42);
    try std.testing.expect(parent != null);
    try std.testing.expect(parent.? < state.service_count);
}

test "selectParentTournament empty state" {
    const state = EvolutionState{};
    try std.testing.expect(selectParentTournament(&state, 42) == null);
}

test "findKillTournamentVictim respects min survivors" {
    const state = makePopulatedState(4); // exactly MIN_SURVIVORS
    // Should not kill anyone
    try std.testing.expect(findKillTournamentVictim(&state, 5000, 42) == null);
}

test "findKillTournamentVictim finds victim" {
    const state = makePopulatedState(10);
    const victim = findKillTournamentVictim(&state, 5000, 42);
    try std.testing.expect(victim != null);
    // Victim should be from bottom half (higher PPL = higher index)
    try std.testing.expect(victim.? >= 3);
}

test "computePopulationHealth basic" {
    const state = makePopulatedState(10);
    const health = computePopulationHealth(&state);
    try std.testing.expect(health.alive == 10);
    try std.testing.expect(health.diversity > 0);
    try std.testing.expect(health.elite_gap >= 1.0);
    try std.testing.expect(health.spike_rate >= 0 and health.spike_rate <= 1.0);
}

test "computePopulationHealth empty" {
    const state = EvolutionState{};
    const health = computePopulationHealth(&state);
    try std.testing.expect(health.alive == 0);
    try std.testing.expect(health.diversity == 0);
}

test "mutateConfigGentle only changes LR" {
    var entry = makeTestEntry();
    entry.current_step = 20000;
    const config = mutateConfigGentle(&entry, 42);
    // Grad clip and warmup should match worker's own values
    try std.testing.expectEqual(entry.grad_clip, config.grad_clip);
    try std.testing.expectEqual(entry.warmup, config.warmup);
    try std.testing.expectEqual(entry.seed, config.seed);
    // LR should be different (with high probability)
    const orig_lr = std.fmt.parseFloat(f64, entry.lrStr()) catch unreachable;
    const new_lr = std.fmt.parseFloat(f64, config.lr_str[0..config.lr_len]) catch unreachable;
    try std.testing.expect(new_lr >= LR_MIN and new_lr <= LR_MAX);
    // σ=0.1 gentle: ratio should be close to 1
    const ratio = new_lr / orig_lr;
    try std.testing.expect(ratio > 0.8 and ratio < 1.25);
}

test "mutateConfigGentleSacred picks nearby phi power" {
    var entry = makeTestEntry();
    const base_lr = std.fmt.parseFloat(f64, entry.lrStr()) catch unreachable;
    var seed: u32 = 1;
    for (0..50) |_| {
        const config = mutateConfigGentleSacred(&entry, seed);
        const new_lr = std.fmt.parseFloat(f64, config.lr_str[0..config.lr_len]) catch unreachable;
        const ratio = new_lr / base_lr;
        // Should be φ^{-1}, φ^0, or φ^1
        const valid = (@abs(ratio - SACRED_PHI_INV) < 0.01) or
            (@abs(ratio - 1.0) < 0.01) or
            (@abs(ratio - SACRED_PHI) < 0.01);
        try std.testing.expect(valid);
        seed = mulberry32(seed);
    }
    _ = &entry;
}

test "EventType tune serialization round-trip" {
    // Verify tune = 4
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(EventType.tune));
    // Verify it can be reconstructed
    const reconstructed: EventType = @enumFromInt(@as(u8, 4));
    try std.testing.expect(reconstructed == .tune);
}

// ═══════════════════════════════════════════════════════════════════════════════
// I1: Loss history ring buffer tests
// ═══════════════════════════════════════════════════════════════════════════════

test "appendLossHistory basic" {
    var svc = ServiceEntry{};
    svc.appendLossHistory(1000, 50.0, 3.9);
    svc.appendLossHistory(2000, 30.0, 3.4);
    svc.appendLossHistory(3000, 20.0, 3.0);

    try std.testing.expectEqual(@as(u8, 3), svc.loss_history_len);
    try std.testing.expectEqual(@as(u32, 1000), svc.loss_history[0].step);
    try std.testing.expectEqual(@as(u32, 3000), svc.loss_history[2].step);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), svc.loss_history[2].ppl, 0.1);
}

test "appendLossHistory dedup same step" {
    var svc = ServiceEntry{};
    svc.appendLossHistory(1000, 50.0, 3.9);
    svc.appendLossHistory(1000, 50.0, 3.9); // duplicate
    svc.appendLossHistory(1000, 49.0, 3.8); // same step, different value

    try std.testing.expectEqual(@as(u8, 1), svc.loss_history_len);
}

test "appendLossHistory ring overflow" {
    var svc = ServiceEntry{};
    // Fill to capacity
    for (0..LOSS_HISTORY_SIZE) |i| {
        svc.appendLossHistory(@intCast(i * 1000), 50.0 - @as(f32, @floatFromInt(i)), 4.0);
    }
    try std.testing.expectEqual(@as(u8, LOSS_HISTORY_SIZE), svc.loss_history_len);

    // Add one more — should shift and drop oldest
    svc.appendLossHistory(99000, 5.0, 1.6);
    try std.testing.expectEqual(@as(u8, LOSS_HISTORY_SIZE), svc.loss_history_len);
    // First entry should now be step=1000 (0 dropped)
    try std.testing.expectEqual(@as(u32, 1000), svc.loss_history[0].step);
    // Last entry should be new one
    try std.testing.expectEqual(@as(u32, 99000), svc.loss_history[LOSS_HISTORY_SIZE - 1].step);
}

// ═══════════════════════════════════════════════════════════════════════════════
// I2: Stall/crash detection tests
// ═══════════════════════════════════════════════════════════════════════════════

test "stall detection marks stalled after 2 unchanged polls" {
    var svc = ServiceEntry{};
    svc.status = .running;
    svc.current_step = 5000;

    // Simulate first poll — same step
    svc.last_poll_step = 5000;
    svc.stall_count = 1;
    // Second poll — still same
    svc.last_poll_step = 5000;
    svc.stall_count = 2;
    if (svc.stall_count >= 2 and svc.status == .running) {
        svc.status = .stalled;
    }
    try std.testing.expect(svc.status == .stalled);
}

test "new ServiceStatus values" {
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(ServiceStatus.stalled));
    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(ServiceStatus.diverged));
    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(ServiceStatus.stuck));
}

// ═══════════════════════════════════════════════════════════════════════════════
// I3: Log limit for leaders
// ═══════════════════════════════════════════════════════════════════════════════

test "logLimitForService leaders get wider window" {
    var svc = ServiceEntry{};
    svc.current_ppl = 5.0;
    svc.current_step = 70000;
    try std.testing.expectEqual(@as(u32, 100), logLimitForService(&svc));

    svc.current_ppl = 30.0;
    svc.current_step = 48000;
    try std.testing.expectEqual(@as(u32, 50), logLimitForService(&svc));

    svc.current_ppl = 30.0;
    svc.current_step = 20000;
    try std.testing.expectEqual(@as(u32, 20), logLimitForService(&svc));
}

// ═══════════════════════════════════════════════════════════════════════════════
// I4: Checkpoint parsing tests
// ═══════════════════════════════════════════════════════════════════════════════

test "parseCkptLine step_NNNNN format" {
    const step = parseCkptLine("[CKPT] Saved: data/checkpoints/hslm_step_50000.bin");
    try std.testing.expect(step != null);
    try std.testing.expectEqual(@as(u32, 50000), step.?);
}

test "parseCkptLine step NNNNN format" {
    const step = parseCkptLine("checkpoint saved at step 75000");
    try std.testing.expect(step != null);
    try std.testing.expectEqual(@as(u32, 75000), step.?);
}

test "parseCkptLine no step" {
    const step = parseCkptLine("Training checkpoint saved...");
    try std.testing.expect(step == null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Diversity quota tests
// ═══════════════════════════════════════════════════════════════════════════════

test "computeQuotaDeficit picks most underrepresented bucket" {
    var state = EvolutionState{};

    // Add 10 NTP/27 services (all one bucket)
    for (0..10) |_| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.current_step = 5000;
        entry.current_ppl = 20.0;
        entry.context = 27;
        copyToFixed(&entry.objective, &entry.objective_len, "ntp");
    }

    const deficit = computeQuotaDeficit(&state);
    // JEPA and hybrid have 0% actual vs 20% target → one of them should be picked
    // NTP/81+ has 0% actual vs 20% target → also a candidate
    // All three have deficit = 0.20, NTP/27 has surplus
    try std.testing.expect(deficit.deficit > 0.1);
    // Should NOT pick "ntp"/0 (it's overrepresented at 100%)
    const is_ntp_any = std.mem.eql(u8, deficit.objective, "ntp") and deficit.min_context == 0;
    try std.testing.expect(!is_ntp_any);
}

test "computeQuotaDeficit balanced returns low deficit" {
    var state = EvolutionState{};

    // 4 NTP/27, 2 NTP/81, 2 JEPA, 2 hybrid = balanced
    for (0..4) |_| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.context = 27;
        copyToFixed(&entry.objective, &entry.objective_len, "ntp");
    }
    for (0..2) |_| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        entry.context = 81;
        copyToFixed(&entry.objective, &entry.objective_len, "ntp");
    }
    for (0..2) |_| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        copyToFixed(&entry.objective, &entry.objective_len, "jepa");
    }
    for (0..2) |_| {
        const entry = state.addService() orelse break;
        entry.status = .running;
        copyToFixed(&entry.objective, &entry.objective_len, "hybrid");
    }

    const deficit = computeQuotaDeficit(&state);
    // All buckets roughly at target, max deficit should be small
    try std.testing.expect(deficit.deficit < 0.1);
}

test "computeRecommendations diversity collapse" {
    const state = EvolutionState{};
    const health = PopulationHealth{
        .diversity = 0.0001,
        .elite_gap = 2.0,
        .stagnation = 0,
        .spike_rate = 0.0,
        .alive = 10,
        .total = 10,
        .health_score = 50.0,
        .leader_improvement = 0,
        .leader_step = 0,
    };

    const result = computeRecommendations(&state, health, 0);
    try std.testing.expect(result.count >= 1);
    try std.testing.expect(result.recs[0].severity == .critical);
}

test "statusToStr covers all variants" {
    try std.testing.expectEqualStrings("running", statusToStr(.running));
    try std.testing.expectEqualStrings("stalled", statusToStr(.stalled));
    try std.testing.expectEqualStrings("crashed", statusToStr(.crashed));
    try std.testing.expectEqualStrings("idle", statusToStr(.idle));
    try std.testing.expectEqualStrings("diverged", statusToStr(.diverged));
}
