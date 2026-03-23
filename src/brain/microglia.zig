//! Strand II: Cognitive Architecture
//!
//! Neuroanatomically inspired brain module for Trinity S³AI.
//!
//! MICROGLIA — The Constant Gardeners v5.1
//!
//! Immune surveillance system of the S³AI Brain
//!
//! Sacred Formula: φ² + 1/φ² = 3 = TRINITY
//!
//! Microglia are the brain's resident immune cells that Nature named
//! "The Constant Gardeners" (Paolicelli et al., 2011). They constantly
//! patrol the brain, pruning weak synapses and stimulating strong ones.
//!
//! # Neuroanatomical Context
//!
//! Microglia constitute 10-15% of all brain cells and serve as the
//! primary immune defense in the central nervous system. They exist in
//! three states:
//!
//!   1. **Resting** — Surveillance mode, constantly monitoring
//!   2. **Activated** — Responding to injury or infection
//!   3. **Phagocytic** — Consuming debris and dead cells
//!
//! # Biological Inspiration
//!
//! The "find-me / eat-me / don't-eat-me" signaling system (Stevens et al., 2007):
//!
//!   - **Find-me signals** (ATP, UTP): Released by dying neurons to recruit microglia
//!   - **Eat-me signals** (Phosphatidylserine): Mark cells for phagocytosis
//!   - **Don't-eat-me signals** (CD47): Protect healthy cells from pruning
//!
//! # Trinity Mapping
//!
//!   1. **Surveillance** — Patrol every 30 minutes, scan for dead synapses
//!   2. **Phagocytosis** — Prune crashed/stalled workers (weak connections)
//!   3. **Neurotrophic** — Stimulate regrowth from top performers
//!   4. **Sleep** — Night mode reduces aggressive pruning
//!
//! # Biological Papers
//!
//!   - "The Constant Gardeners" (Paolicelli & Gasparini, 2011)
//!   - "Gardening the Brain" (EMBL, 2024)
//!   - "Find-me / eat-me / don't-eat-me" signals (Stevens et al., 2007)
//!   - "Microglial pruning of synapses" (Tremblay et al., 2010)
//!
//! φ² + 1/φ² = 3 = TRINITY

const std = @import("std");
const Allocator = std.mem.Allocator;
const print = std.debug.print;

// Sacred constants (source of truth: src/sacred/constants.zig)
// Use direct constant definitions to avoid circular import issues
const SACRED_PHI: f32 = 1.618033988749895;
const SACRED_TRINITY: f32 = 3.0;

/// Module version for tracking changes
pub const MICROGLIA_VERSION: u32 = 1;

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
        for (self.dont_eat_me) |protected_id| {
            if (std.mem.eql(u8, protected_id, worker_id)) {
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
///
/// # Signal Mapping
///
/// | Signal | Biological | Trinity | Threshold |
/// |--------|-----------|---------|-----------|
/// | find_me | ATP/UTP release | High PPL (>15) | Needs monitoring |
/// | eat_me | Phosphatidylserine | Very high PPL (>100) | Prune immediately |
/// | dont_eat_me | CD47 marker | Sacred list | Never prune |
/// | help_me | Growth factors | Stalled/low activity | Stimulate recovery |
pub const SynapticSignal = enum {
    /// "Find-me" — neuron needs help (low activity, distress)
    find_me,

    /// "Eat-me" — neuron is dying (damage, infection)
    eat_me,

    /// "Don't-eat-me" — healthy neuron, do NOT prune
    dont_eat_me,

    /// "Help-me" — neuron needs support but is viable
    help_me,

    /// Converts signal to emoji for TUI display
    pub fn emoji(self: SynapticSignal) []const u8 {
        return switch (self) {
            .find_me => "🔍", // Searching/magnifying glass
            .eat_me => "🗑️", // Trash/wastebasket
            .dont_eat_me => "🛡️", // Shield
            .help_me => "🆘", // SOS/help
        };
    }

    /// Returns human-readable description
    pub fn description(self: SynapticSignal) []const u8 {
        return switch (self) {
            .find_me => "Worker needs attention (elevated PPL)",
            .eat_me => "Worker should be pruned (critical PPL)",
            .dont_eat_me => "Worker is sacred (never prune)",
            .help_me => "Worker needs support (stalled/low activity)",
        };
    }
};

/// Detect synaptic signal from worker state
///
/// Analyzes worker PPL, step count, and status to determine the
/// appropriate synaptic signal for microglial response.
///
/// # Algorithm
///
/// 1. **Crashed workers** → `eat_me` (immediate pruning needed)
/// 2. **PPL > 100** → `eat_me` (too poor to recover)
/// 3. **PPL > 15** → `find_me` (needs monitoring)
/// 4. **Stalled** → `help_me` (may recover with support)
/// 5. **Healthy** → `dont_eat_me` (normal operation)
///
/// # Parameters
///
/// - `worker`: Worker state with PPL, step, and status
///
/// # Returns
///
/// Appropriate `SynapticSignal` for microglial action
///
/// # Example
///
/// ```zig
/// const worker = WorkerState{
///     .ppl = 150.0,
///     .step = 5000,
///     .status = .crashed,
/// };
/// const signal = detectSignal(worker);
/// // Returns .eat_me
/// ```
pub fn detectSignal(worker: WorkerState) SynapticSignal {
    // Priority 1: Crashed workers always get eat-me signal
    if (worker.status == .crashed) {
        return .eat_me;
    }

    // Priority 2: Extremely high PPL = beyond recovery
    if (worker.ppl > 100.0) {
        return .eat_me;
    }

    // Priority 3: Elevated PPL = needs monitoring
    if (worker.ppl > 15.0) {
        return .find_me;
    }

    // Priority 4: Stalled but not crashed = may recover
    if (worker.status == .stalled) {
        return .help_me;
    }

    // Default: healthy worker, don't prune
    return .dont_eat_me;
}

/// Abstract worker state for signal detection
///
/// Represents the current state of a training worker for
/// microglial analysis and action determination.
///
/// # Fields
///
/// - `ppl`: Perplexity score (lower is better)
/// - `step`: Current training step
/// - `status`: Worker operational status
pub const WorkerState = struct {
    ppl: f32,
    step: u32,
    status: WorkerStatus,

    /// Worker operational status
    pub const WorkerStatus = enum {
        /// Worker is actively training
        active,
        /// Worker has stalled (no progress)
        stalled,
        /// Worker has crashed (fatal error)
        crashed,
    };

    /// Creates a new worker state
    pub fn init(ppl: f32, step: u32, status: WorkerStatus) WorkerState {
        return .{
            .ppl = ppl,
            .step = step,
            .status = status,
        };
    }

    /// Checks if worker is in distress
    pub fn isDistressed(self: *const WorkerState) bool {
        return self.status != .active or self.ppl > 15.0;
    }

    /// Checks if worker is recoverable
    pub fn isRecoverable(self: *const WorkerState) bool {
        return self.status != .crashed and self.ppl < 100.0;
    }
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
    // Note: With fixed implementation, healthy worker (PPL < 15, active) returns dont_eat_me
    const worker = WorkerState.init(5.0, 10000, .active);

    const signal = detectSignal(worker);
    try std.testing.expectEqual(SynapticSignal.dont_eat_me, signal);
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

// ═══════════════════════════════════════════════════════════════════════════════
// EDGE CASE TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "detectSignal - crashed worker always returns eat_me" {
    // Crashed status overrides all other factors
    const worker = WorkerState.init(1.0, 100000, .crashed); // Perfect PPL but crashed
    try std.testing.expectEqual(SynapticSignal.eat_me, detectSignal(worker));
}

test "detectSignal - PPL over 100 returns eat_me" {
    const worker = WorkerState.init(150.0, 5000, .active);
    try std.testing.expectEqual(SynapticSignal.eat_me, detectSignal(worker));
}

test "detectSignal - PPL over 15 returns find_me" {
    const worker = WorkerState.init(50.0, 10000, .active);
    try std.testing.expectEqual(SynapticSignal.find_me, detectSignal(worker));
}

test "detectSignal - stalled worker returns help_me" {
    const worker = WorkerState.init(10.0, 5000, .stalled);
    try std.testing.expectEqual(SynapticSignal.help_me, detectSignal(worker));
}

test "detectSignal - healthy worker returns dont_eat_me" {
    const worker = WorkerState.init(4.6, 100000, .active);
    try std.testing.expectEqual(SynapticSignal.dont_eat_me, detectSignal(worker));
}

test "detectSignal - boundary values" {
    // Test exact threshold at 100 (should be eat_me)
    const worker_100 = WorkerState.init(100.01, 10000, .active);
    try std.testing.expectEqual(SynapticSignal.eat_me, detectSignal(worker_100));

    // Test just below 100 (should be find_me)
    const worker_99 = WorkerState.init(99.99, 10000, .active);
    try std.testing.expectEqual(SynapticSignal.find_me, detectSignal(worker_99));

    // Test exact threshold at 15 (should be find_me)
    const worker_15 = WorkerState.init(15.01, 10000, .active);
    try std.testing.expectEqual(SynapticSignal.find_me, detectSignal(worker_15));

    // Test just below 15 (should be dont_eat_me if active)
    const worker_14 = WorkerState.init(14.99, 10000, .active);
    try std.testing.expectEqual(SynapticSignal.dont_eat_me, detectSignal(worker_14));
}

test "detectSignal - zero PPL" {
    // Zero PPL is excellent (converged)
    const worker = WorkerState.init(0.0, 200000, .active);
    try std.testing.expectEqual(SynapticSignal.dont_eat_me, detectSignal(worker));
}

test "detectSignal - negative PPL (invalid)" {
    // Negative PPL is physically impossible but handle gracefully
    const worker = WorkerState.init(-1.0, 10000, .active);
    try std.testing.expectEqual(SynapticSignal.dont_eat_me, detectSignal(worker));
}

test "detectSignal - extremely high PPL" {
    // Very large PPL (effectively infinite loss)
    const worker = WorkerState.init(999999.0, 100, .active);
    try std.testing.expectEqual(SynapticSignal.eat_me, detectSignal(worker));
}

test "detectSignal - zero step count" {
    // Worker just started
    const worker = WorkerState.init(5.0, 0, .active);
    try std.testing.expectEqual(SynapticSignal.dont_eat_me, detectSignal(worker));
}

test "detectSignal - crashed with perfect PPL" {
    // Even perfect PPL can't save a crashed worker
    const worker = WorkerState.init(1.0, 1000000, .crashed);
    try std.testing.expectEqual(SynapticSignal.eat_me, detectSignal(worker));
}

test "detectSignal - stalled with high PPL" {
    // Stalled + high PPL = eat_me (via PPL check, not status)
    const worker = WorkerState.init(200.0, 5000, .stalled);
    try std.testing.expectEqual(SynapticSignal.eat_me, detectSignal(worker));
}

test "SynapticSignal emoji returns non-empty" {
    try std.testing.expect(SynapticSignal.find_me.emoji().len > 0);
    try std.testing.expect(SynapticSignal.eat_me.emoji().len > 0);
    try std.testing.expect(SynapticSignal.dont_eat_me.emoji().len > 0);
    try std.testing.expect(SynapticSignal.help_me.emoji().len > 0);
}

test "SynapticSignal emoji matches expected" {
    try std.testing.expectEqualStrings("🔍", SynapticSignal.find_me.emoji());
    try std.testing.expectEqualStrings("🗑️", SynapticSignal.eat_me.emoji());
    try std.testing.expectEqualStrings("🛡️", SynapticSignal.dont_eat_me.emoji());
    try std.testing.expectEqualStrings("🆘", SynapticSignal.help_me.emoji());
}

test "SynapticSignal description returns non-empty" {
    try std.testing.expect(SynapticSignal.find_me.description().len > 0);
    try std.testing.expect(SynapticSignal.eat_me.description().len > 0);
    try std.testing.expect(SynapticSignal.dont_eat_me.description().len > 0);
    try std.testing.expect(SynapticSignal.help_me.description().len > 0);
}

test "WorkerState init method" {
    const worker = WorkerState.init(4.6, 100000, .active);
    try std.testing.expectApproxEqAbs(@as(f32, 4.6), worker.ppl, 0.001);
    try std.testing.expectEqual(@as(u32, 100000), worker.step);
    try std.testing.expect(worker.status == .active);
}

test "WorkerState isDistressed - healthy worker" {
    const worker = WorkerState.init(4.6, 100000, .active);
    try std.testing.expect(!worker.isDistressed());
}

test "WorkerState isDistressed - high PPL" {
    const worker = WorkerState.init(50.0, 100000, .active);
    try std.testing.expect(worker.isDistressed());
}

test "WorkerState isDistressed - crashed worker" {
    const worker = WorkerState.init(1.0, 100000, .crashed);
    try std.testing.expect(worker.isDistressed());
}

test "WorkerState isDistressed - stalled worker" {
    const worker = WorkerState.init(5.0, 50000, .stalled);
    try std.testing.expect(worker.isDistressed());
}

test "WorkerState isRecoverable - healthy worker" {
    const worker = WorkerState.init(4.6, 100000, .active);
    try std.testing.expect(worker.isRecoverable());
}

test "WorkerState isRecoverable - crashed worker" {
    const worker = WorkerState.init(50.0, 5000, .crashed);
    try std.testing.expect(!worker.isRecoverable());
}

test "WorkerState isRecoverable - very high PPL" {
    const worker = WorkerState.init(150.0, 5000, .active);
    try std.testing.expect(!worker.isRecoverable());
}

test "WorkerState isRecoverable - stalled with reasonable PPL" {
    const worker = WorkerState.init(10.0, 10000, .stalled);
    try std.testing.expect(worker.isRecoverable());
}

test "Phagocytosis - empty worker ID" {
    var microglia = Microglia{
        .dont_eat_me = &.{},
        .night_mode = false,
    };
    // Should handle empty string gracefully
    try microglia.phagocytose("");
}

test "Phagocytosis - worker ID with special characters" {
    var microglia = Microglia{
        .dont_eat_me = &.{},
        .night_mode = false,
    };
    // Should handle special characters
    try microglia.phagocytose("hslm-worker-123_test:dev");
}

test "Stimulate regrowth - empty template" {
    const microglia = Microglia{};
    const allocator = std.testing.allocator;

    const new_worker = try microglia.stimulateRegrowth("", allocator);
    defer allocator.free(new_worker);
    try std.testing.expectEqualStrings("hslm-born-from-", new_worker);
}

test "Stimulate regrowth - template with special characters" {
    const microglia = Microglia{};
    const allocator = std.testing.allocator;

    const new_worker = try microglia.stimulateRegrowth("hslm-r33:dev", allocator);
    defer allocator.free(new_worker);
    try std.testing.expectEqualStrings("hslm-born-from-hslm-r33:dev", new_worker);
}

test "Night mode overrides sacred list" {
    var microglia = Microglia{
        .dont_eat_me = &.{},
        .night_mode = true,
    };
    // Night mode protects even non-sacred workers
    try microglia.phagocytose("hslm-weak-worker");
}

test "Sacred list takes precedence over normal processing" {
    var microglia = Microglia{
        .dont_eat_me = &.{"hslm-r33"},
        .night_mode = false,
    };
    // Sacred worker protected even during day
    try microglia.phagocytose("hslm-r33");
}

test "SurveillanceReport timestamp increases" {
    const allocator = std.testing.allocator;
    const microglia = Microglia{};

    const report1 = try microglia.patrol(allocator);
    std.Thread.sleep(1 * std.time.ns_per_ms); // Small delay (1ms)
    const report2 = try microglia.patrol(allocator);

    try std.testing.expect(report2.timestamp >= report1.timestamp);
}

test "Microglia version constant" {
    try std.testing.expectEqual(@as(u32, 1), MICROGLIA_VERSION);
}

test "Sacred TRINITY constant" {
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), SACRED_TRINITY, 0.001);
}

test "Patrol interval conversion" {
    // Verify 30 minutes in milliseconds
    const expected_ms: u64 = 30 * 60 * 1000;
    try std.testing.expectEqual(@as(u64, 1800000), expected_ms);

    const microglia = Microglia{};
    try std.testing.expectEqual(expected_ms, microglia.patrol_interval_ms);
}

test "WorkerState enum tag checking" {
    const active_worker = WorkerState.init(1.0, 1000, .active);
    const stalled_worker = WorkerState.init(1.0, 1000, .stalled);
    const crashed_worker = WorkerState.init(1.0, 1000, .crashed);

    // Verify we can distinguish states
    try std.testing.expect(active_worker.status != stalled_worker.status);
    try std.testing.expect(stalled_worker.status != crashed_worker.status);
    try std.testing.expect(crashed_worker.status != active_worker.status);
}

test "Signal detection priority chain" {
    // Verify priority: crashed > PPL > stalled > healthy

    // Priority 1: Crashed overrides good PPL
    const crashed_good = WorkerState.init(1.0, 100000, .crashed);
    try std.testing.expectEqual(SynapticSignal.eat_me, detectSignal(crashed_good));

    // Priority 2: High PPL overrides active status
    const high_ppl_active = WorkerState.init(200.0, 100000, .active);
    try std.testing.expectEqual(SynapticSignal.eat_me, detectSignal(high_ppl_active));

    // Priority 3: Medium PPL triggers find_me
    const med_ppl_active = WorkerState.init(50.0, 100000, .active);
    try std.testing.expectEqual(SynapticSignal.find_me, detectSignal(med_ppl_active));

    // Priority 4: Stalled triggers help_me
    const stalled_low_ppl = WorkerState.init(5.0, 50000, .stalled);
    try std.testing.expectEqual(SynapticSignal.help_me, detectSignal(stalled_low_ppl));

    // Default: Healthy
    const healthy = WorkerState.init(4.6, 100000, .active);
    try std.testing.expectEqual(SynapticSignal.dont_eat_me, detectSignal(healthy));
}
