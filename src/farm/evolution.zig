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
const sevo_mod = @import("sevo.zig");

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
