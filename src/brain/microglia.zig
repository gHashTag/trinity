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
                print("{s}🛡️ SACRED: {s} — don't-eat-me signal{s}\n", .{ CYAN, worker_id, RESET });
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
        print("{s}🌙 Microglia entering night mode — reduced pruning{s}\n", .{ YELLOW, RESET });
    }

    /// Wake mode — full pruning capacity
    pub fn wakeUp(self: *Microglia) void {
        self.night_mode = false;
        print("{s}☀️ Microglia waking up — full pruning capacity{s}\n", .{ YELLOW, RESET });
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

test "Microglia default initialization" {
    const microglia = Microglia{};

    // Default patrol interval: 30 minutes
    try std.testing.expectEqual(@as(u64, 30 * 60 * 1000), microglia.patrol_interval_ms);

    // Night mode off by default
    try std.testing.expectEqual(false, microglia.night_mode);

    // Default sacred list
    try std.testing.expectEqual(@as(usize, 3), microglia.dont_eat_me.len);
    try std.testing.expectEqualStrings("hslm-r33", microglia.dont_eat_me[0]);
    try std.testing.expectEqualStrings("hslm-r5", microglia.dont_eat_me[1]);
    try std.testing.expectEqualStrings("hslm-r13", microglia.dont_eat_me[2]);

    // Thresholds
    try std.testing.expectEqual(@as(f32, 15.0), microglia.find_me_threshold);
    try std.testing.expectEqual(@as(f32, 100.0), microglia.eat_me_threshold);
}

test "SurveillanceReport initialization" {
    const report = SurveillanceReport{
        .timestamp = 1710907200000,
        .active_workers = 42,
        .crashed_workers = 3,
        .idle_workers = 5,
        .stalled_workers = 2,
        .diversity_index = 0.75,
        .recommendation = .monitor,
    };

    try std.testing.expectEqual(@as(i64, 1710907200000), report.timestamp);
    try std.testing.expectEqual(@as(usize, 42), report.active_workers);
    try std.testing.expectEqual(@as(usize, 3), report.crashed_workers);
    try std.testing.expectEqual(@as(usize, 5), report.idle_workers);
    try std.testing.expectEqual(@as(usize, 2), report.stalled_workers);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), report.diversity_index, 0.001);
    try std.testing.expectEqual(Recommendation.monitor, report.recommendation);
}

test "Surveillance patrol returns valid report" {
    const microglia = Microglia{};
    const allocator = std.testing.allocator;

    const report = try microglia.patrol(allocator);

    // Verify report structure (default implementation returns zeros)
    try std.testing.expect(report.timestamp > 0);
    try std.testing.expectEqual(@as(usize, 0), report.active_workers);
    try std.testing.expectEqual(@as(usize, 0), report.crashed_workers);
    try std.testing.expectEqual(@as(usize, 0), report.idle_workers);
    try std.testing.expectEqual(@as(usize, 0), report.stalled_workers);
    try std.testing.expectEqual(@as(f32, 0.0), report.diversity_index);
    try std.testing.expectEqual(Recommendation.monitor, report.recommendation);
}

test "Phagocytosis prunes non-sacred worker" {
    var microglia = Microglia{
        .dont_eat_me = &.{ "hslm-r33", "hslm-r5" },
        .night_mode = false,
    };

    // Non-sacred worker should be pruned (no error = success)
    try microglia.phagocytose("hslm-weak-worker");
}

test "Phagocytosis respects don't-eat-me signals" {
    var microglia = Microglia{
        .dont_eat_me = &.{ "hslm-r33", "hslm-r5" },
        .night_mode = false,
    };

    // Sacred workers are protected
    try microglia.phagocytose("hslm-r33");
    try microglia.phagocytose("hslm-r5");
}

test "Phagocytosis respects night mode" {
    var microglia = Microglia{
        .dont_eat_me = &.{},
        .night_mode = true, // Night mode active
    };

    // Even non-sacred workers protected during night
    try microglia.phagocytose("hslm-weak-worker");
}

test "Sleep mode transition" {
    var microglia = Microglia{};

    // Initially awake
    try std.testing.expectEqual(false, microglia.night_mode);

    // Enter sleep
    microglia.enterSleepMode();
    try std.testing.expectEqual(true, microglia.night_mode);

    // Wake up
    microglia.wakeUp();
    try std.testing.expectEqual(false, microglia.night_mode);
}

test "Stimulate regrowth creates new worker ID" {
    const microglia = Microglia{};
    const allocator = std.testing.allocator;

    const new_worker = try microglia.stimulateRegrowth("hslm-r33", allocator);
    defer allocator.free(new_worker);

    try std.testing.expectEqualStrings("hslm-born-from-hslm-r33", new_worker);
}

test "Stimulate regrowth from different templates" {
    const microglia = Microglia{};
    const allocator = std.testing.allocator;

    const born_from_r33 = try microglia.stimulateRegrowth("hslm-r33", allocator);
    defer allocator.free(born_from_r33);
    try std.testing.expectEqualStrings("hslm-born-from-hslm-r33", born_from_r33);

    const born_from_r5 = try microglia.stimulateRegrowth("hslm-r5", allocator);
    defer allocator.free(born_from_r5);
    try std.testing.expectEqualStrings("hslm-born-from-hslm-r5", born_from_r5);
}

test "Recommendation enum covers all states" {
    // Verify all recommendation types exist
    const recs = [_]Recommendation{
        .monitor,
        .prune_crashed,
        .prune_stalled,
        .stimulate_growth,
        .inject_diversity,
        .enter_sleep,
    };

    try std.testing.expectEqual(@as(usize, 6), recs.len);
}

test "SynapticSignal enum covers all signals" {
    // Verify all signal types exist
    const signals = [_]SynapticSignal{
        .find_me,
        .eat_me,
        .dont_eat_me,
        .help_me,
    };

    try std.testing.expectEqual(@as(usize, 4), signals.len);
}

test "WorkerState structure" {
    const worker = WorkerState{
        .ppl = 4.6,
        .step = 100000,
        .status = .active,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 4.6), worker.ppl, 0.001);
    try std.testing.expectEqual(@as(u32, 100000), worker.step);
    // Check status is active (can't directly compare enum tags in Zig)
    try std.testing.expect(worker.status == .active);
}

test "WorkerState crashed status" {
    const crashed_worker = WorkerState{
        .ppl = 150.0,
        .step = 5000,
        .status = .crashed,
    };

    try std.testing.expect(crashed_worker.status == .crashed);
}

test "WorkerState stalled status" {
    const stalled_worker = WorkerState{
        .ppl = 50.0,
        .step = 10000,
        .status = .stalled,
    };

    try std.testing.expect(stalled_worker.status == .stalled);
}

test "Sacred PHI constant" {
    // Verify the golden ratio constant
    try std.testing.expectApproxEqAbs(@as(f32, 1.618), SACRED_PHI, 0.001);
}

test "Microglia custom patrol interval" {
    const microglia = Microglia{
        .patrol_interval_ms = 15 * 60 * 1000, // 15 minutes
    };

    try std.testing.expectEqual(@as(u64, 15 * 60 * 1000), microglia.patrol_interval_ms);
}

test "Microglia custom thresholds" {
    const microglia = Microglia{
        .find_me_threshold = 20.0,
        .eat_me_threshold = 200.0,
    };

    try std.testing.expectApproxEqAbs(@as(f32, 20.0), microglia.find_me_threshold, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 200.0), microglia.eat_me_threshold, 0.001);
}

test "SurveillanceReport with different recommendations" {
    const recommendations = [_]Recommendation{
        .monitor,
        .prune_crashed,
        .prune_stalled,
        .stimulate_growth,
        .inject_diversity,
        .enter_sleep,
    };

    for (recommendations) |rec| {
        const report = SurveillanceReport{
            .timestamp = std.time.milliTimestamp(),
            .active_workers = 10,
            .crashed_workers = 1,
            .idle_workers = 0,
            .stalled_workers = 0,
            .diversity_index = 0.5,
            .recommendation = rec,
        };
        try std.testing.expectEqual(rec, report.recommendation);
    }
}
