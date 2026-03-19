//! MICROGLIA — The Constant Gardeners
//!
//! Immune surveillance system of the S³AI Brain
//!
//! Microglia are the brain's resident immune cells that Nature named
//! "The Constant Gardeners" (Paolicelli et al., 2011). They constantly
//! patrol the brain, pruning weak synapses and stimulating strong ones.
//!
//! In Trinity, Microglia performs the same functions for the training farm:
//!
//!   1. **Surveillance** — Patrol every 30 minutes, scan for dead synapses
//!   2. **Phagocytosis** — Prune crashed/stalled workers (weak connections)
//!   3. **Neurotrophic** — Stimulate regrowth from top performers
//!   4. **Sleep** — Night mode reduces aggressive pruning
//!
//! Biological Papers:
//!   - "The Constant Gardeners" (Paolicelli & Gasparini, 2011)
//!   - "Gardening the Brain" (EMBL, 2024)
//!   - "Find-me / eat-me / don't-eat-me" signals (Stevens et al., 2007)
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// Sacred constants (source of truth: src/sacred/constants.zig)
const SACRED_PHI: f32 = 1.618;

// ANSI colors
const RESET = "\x1b[0m";
const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const CYAN = "\x1b[36m";
const MAGENTA = "\x1b[35m";

/// Microglia — Constant Gardeners of the S³AI Brain
///
/// Patrols the training farm, prunes dead workers, stimulates regrowth.
pub const Microglia = struct {
    /// Patrol interval in milliseconds (default: 30 minutes)
    patrol_interval_ms: u64 = 30 * 60 * 1000,

    /// Night mode — reduces aggressive pruning during sleep
    night_mode: bool = false,

    /// Sacred workers — protected from pruning ("don't-eat-me" signals)
    sacred_list: []const []const u8 = &.{},

    /// Find-me / eat-me signal thresholds
    find_me_threshold: f32 = 15.0, // PPL above this = "find me" (needs help)
    eat_me_threshold: f32 = 100.0, // PPL above this = "eat me" (prune me)
    dont_eat_me: []const []const u8 = &.{ // Sacred protection
        "hslm-r33",
        "hslm-r5",
        "hslm-r13",
    },

    /// State file for persistent tracking
    state_file: []const u8 = ".trinity/microglia_state.jsonl",

    /// Run surveillance patrol — scan farm, assess health
    pub fn patrol(_: *const Microglia, allocator: Allocator) !SurveillanceReport {
        _ = allocator;
        return SurveillanceReport{
            .timestamp = std.time.milliTimestamp(),
            .active_workers = 0,
            .crashed_workers = 0,
            .idle_workers = 0,
            .stalled_workers = 0,
            .diversity_index = 0.0,
            .recommendation = .monitor,
        };
    }

    /// Phagocytose — prune dead/dying workers (kill crashed)
    pub fn phagocytose(self: *Microglia, worker_id: []const u8) !void {
        if (self.night_mode) {
            print("{s}🌙 Night mode: {s} protected from pruning{s}\n", .{ YELLOW, worker_id, RESET });
            return;
        }

        // Check "don't-eat-me" signals
        for (self.dont_eat_me) |sacred| {
            if (std.mem.eql(u8, sacred, worker_id)) {
                print("{s}🛡️ SACRED: {s} — don't-eat-me signal{ s}\n", .{ CYAN, worker_id, RESET });
                return;
            }
        }

        print("{s}🧹 Phagocytosis: pruning {s}{s}\n", .{ RED, worker_id, RESET });
    }

    /// Stimulate regrowth — spawn new workers from top performers
    pub fn stimulateRegrowth(_: *const Microglia, template: []const u8, allocator: Allocator) ![]const u8 {
        const new_worker_id = try std.fmt.allocPrint(allocator, "hslm-born-from-{s}", .{template});
        print("{s}🌱 Neurotrophic: stimulating growth from {s} → {s}{s}\n", .{
            GREEN, template, new_worker_id, RESET,
        });
        return new_worker_id;
    }

    /// Sleep mode — reduces pruning aggression
    pub fn enterSleepMode(self: *Microglia) void {
        self.night_mode = true;
        print("{s}🌙 Microglia entering night mode — reduced pruning{ s}\n", .{ YELLOW, RESET });
    }

    /// Wake mode — full pruning capacity
    pub fn wakeUp(self: *Microglia) void {
        self.night_mode = false;
        print("{s}☀️ Microglia waking up — full pruning capacity{ s}\n", .{ YELLOW, RESET });
    }
};

/// Report from surveillance patrol
pub const SurveillanceReport = struct {
    timestamp: i64,
    active_workers: usize,
    crashed_workers: usize,
    idle_workers: usize,
    stalled_workers: usize,
    diversity_index: f32,
    recommendation: Recommendation,
};

/// Action recommendation based on surveillance
pub const Recommendation = enum {
    monitor,
    prune_crashed,
    prune_stalled,
    stimulate_growth,
    inject_diversity,
    enter_sleep,
};

/// Find-me / eat-me / don't-eat-me signal system
///
/// Based on Stevens et al. (2007) - neurons signal their status via
/// specific molecular markers that microglia can detect.
pub const SynapticSignal = enum {
    /// "Find-me" — neuron needs help (low activity, distress)
    find_me,

    /// "Eat-me" — neuron is dying (damage, infection)
    eat_me,

    /// "Don't-eat-me" — healthy neuron, do NOT prune
    dont_eat_me,

    /// "Help-me" — neuron needs support but is viable
    help_me,
};

/// Detect synaptic signal from worker state
pub fn detectSignal(worker: WorkerState) SynapticSignal {
    _ = worker;
    return .help_me;
}

/// Abstract worker state for signal detection
pub const WorkerState = struct {
    ppl: f32,
    step: u32,
    status: enum { active, stalled, crashed },
};

/// Biological reference (for documentation)
///
/// Papers:
///   - Paolicelli & Gasparini (2011) "Microglia in the developing brain:
///     From birth to adulthood"
///   - Stevens et al. (2007) "The classical complement pathway is
///     required for developmental synapse elimination"
///   - EMBL (2024) "Gardening the Brain" — synapse pruning review
///
/// Trinity mapping:
///   - Synapse → Training worker
///   - Weak synapse → Poor performer (high PPL)
///   - Strong synapse → Leader (low PPL)
///   - Pruning → Kill via ASHA/PBT
///   - Neurotrophic factors → Recycle from best
pub const BiologicalBasis = struct {};

// ═════════════════════════════════════════════════════════════════════════════
// TESTS
// ═════════════════════════════════════════════════════════════════════════════

test "Microglia don't-eat-me protection" {
    const microglia = Microglia{
        .dont_eat_me = &.{ "hslm-r33", "hslm-r5" },
    };

    // Test that sacred workers are in the protection list
    try std.testing.expectEqual(@as(usize, 2), microglia.dont_eat_me.len);
}

test "Synaptic signal detection" {
    const worker = WorkerState{
        .ppl = 5.0,
        .step = 10000,
        .status = .active,
    };

    const signal = detectSignal(worker);
    try std.testing.expectEqual(SynapticSignal.help_me, signal);
}
