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

// Local farm zone imports
const railway_api = @import("railway_api.zig");
const RailwayApi = railway_api.RailwayApi;
const farm_ws = @import("tri_farm_ws.zig");
const hippocampus = @import("hippocampus.zig");
const experience_hooks = @import("experience_hooks.zig");
// sevo_mod removed — unused import caused circular dependency with farm.evolution export

const tri_commands = @import("tri_commands");
const bench = @import("bench");
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

// ═══════════════════════════════════════════════════════════════════════════════
// PUBLIC API — runEvolveCommand entry point
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runEvolveCommand(allocator: Allocator, args: []const []const u8) !void {
    const subcmd = if (args.len > 0) args[0] else "help";

    if (std.mem.eql(u8, subcmd, "sevo")) {
        // Delegate to sevo module
        const sevo_mod = @import("sevo.zig");
        return sevo_mod.runSevoCommand(allocator, args[1..]);
    } else if (std.mem.eql(u8, subcmd, "help") or std.mem.eql(u8, subcmd, "--help")) {
        printEvolveHelp();
    } else {
        print("{s}Unknown evolve subcommand: {s}{s}\n", .{ RED, subcmd, RESET });
        printEvolveHelp();
    }
}

fn printEvolveHelp() void {
    print("\n{s}TRI FARM EVOLVE — ASHA+PBT Hybrid Evolution{s}\n", .{ BOLD, RESET });
    print("{s}═══════════════════════════════════════════════════════════════════{s}\n\n", .{ DIM, RESET });
    print("Commands:\n", .{});
    print("  tri farm evolve sevo <subcmd>  — SEVO hyperparameter optimization\n", .{});
    print("\nSEVO subcommands:\n", .{});
    print("  list           — List available waves\n", .{});
    print("  inject <wave>  — Execute wave (inject configs)\n", .{});
    print("  wave <wave>    — Same as inject\n", .{});
    print("\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════════
// TYPES (for sevo.zig compatibility)
// ═══════════════════════════════════════════════════════════════════════════════

pub const EvolutionState = struct {
    // Stub for now — full implementation would track ASHA rungs, PBT mutations
    services: [10]ServiceEntry = undefined,
    service_count: usize = 0,

    pub fn addEvent(self: *EvolutionState, event_type: EventType, service: []const u8, detail: []const u8) void {
        _ = self;
        _ = event_type;
        _ = service;
        _ = detail;
        // Stub — full implementation would log to event history
    }
};

pub const EventType = enum {
    spawn,
    recycle,
    kill,
};

pub const ServiceEntry = struct {
    account_idx: usize = 0,
    current_step: u32 = 0,
    status: enum { crashed, stalled, diverged, stuck, idle, killed } = .idle,

    pub fn svcName(self: *const ServiceEntry) []const u8 {
        _ = self;
        return "worker";
    }
};

pub const MutatedConfig = struct {
    lr_str: [32]u8 = undefined,
    lr_len: usize = 0,
    batch_str: [16]u8 = undefined,
    batch_len: usize = 0,
    optimizer_str: [16]u8 = undefined,
    optimizer_len: usize = 0,
    seed: u32 = 0,
    grad_clip: f32 = 1.0,
    warmup: u32 = 2000,
    lr_schedule: LrSchedule = .cosine,
    context: u32 = 81,
    sacred: bool = true,
    objective: []const u8 = "ntp",
    fresh: bool = false,
};

pub const LrSchedule = enum {
    cosine,
    sacred,
    flat,
    phi_restart,
    d2z,
    wsd,
};

// Stub functions for sevo.zig compatibility
pub fn loadState(allocator: Allocator) !EvolutionState {
    _ = allocator;
    return EvolutionState{};
}

pub fn saveState(state: EvolutionState) !void {
    _ = state;
    return error.NotImplemented;
}

pub fn collectMetricsSevo(allocator: Allocator, state: *EvolutionState, api_calls: *u32) void {
    _ = allocator;
    _ = state;
    _ = api_calls;
}

pub fn sortByPpl(state: *EvolutionState, candidates: []usize) void {
    _ = state;
    _ = candidates;
}

pub fn recycleService(
    allocator: Allocator,
    state: *EvolutionState,
    target_idx: usize,
    config: MutatedConfig,
    name: []const u8,
    api_calls: *u32,
) void {
    _ = allocator;
    _ = state;
    _ = target_idx;
    _ = config;
    _ = name;
    _ = api_calls;
}

// MAX_SERVICES constant for sevo.zig
pub const MAX_SERVICES = 152;

// ═══════════════════════════════════════════════════════════════════════════════
// runInjectBatch — Batch config injection (stub for farm_from_issues.zig)
// ═══════════════════════════════════════════════════════════════════════════════

pub fn runInjectBatch(
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
    _ = allocator;
    _ = count;
    _ = sacred;
    _ = dry_run;
    _ = force_recycle;
    _ = objective;
    _ = nca_steps;
    _ = nca_entropy_min;
    _ = nca_entropy_max;
    _ = override_context;
    _ = override_sched;
    _ = force_fresh;
    _ = use_quotas;
    // Stub — full implementation would inject configs into farm workers
    print("{s}⚠️  runInjectBatch is stub — not implemented{s}\n", .{ YELLOW, RESET });
    return error.NotImplemented;
}
