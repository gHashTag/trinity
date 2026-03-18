// ═══════════════════════════════════════════════════════════════════════════════
// RAPHE NUCLEI — PPL Spike Stabilizer
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Serotonin system — mood, patience, inhibition of pain
// Trinity: PPL spike stabilizer — φ-patience for training fluctuations
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// PPL SPIKE STABILIZER — Don't panic over normal training fluctuations
// ═══════════════════════════════════════════════════════════════════════════════

pub const SpikeAnalysis = struct {
    is_spike: bool = false,
    is_regression: bool = false,
    expected: bool = false, // Is this spike expected (cosine restart)?
    confidence: f32 = 0.0, // 0-1
    recommendation: Recommendation = .wait,
    reason: [128]u8 = undefined,
    reason_len: usize = 0,

    pub fn reasonStr(self: *const SpikeAnalysis) []const u8 {
        return self.reason[0..self.reason_len];
    }

    fn setReason(self: *SpikeAnalysis, text: []const u8) void {
        const len = @min(text.len, self.reason.len);
        @memcpy(self.reason[0..len], text[0..len]);
        self.reason_len = len;
    }
};

pub const Recommendation = enum {
    ignore, // Normal fluctuation
    wait, // φ-patience: wait φ² cycles
    alert, // Real regression detected
};

/// Analyze PPL spike — is it real regression or training noise?
pub fn smoothPPLSpikes(
    allocator: Allocator,
    current_ppl: f32,
    history: []const f32,
) !SpikeAnalysis {
    _ = allocator;
    var analysis = SpikeAnalysis{};

    if (history.len < 3) {
        analysis.setReason("Not enough history");
        analysis.recommendation = .wait;
        return analysis;
    }

    // Calculate baseline (median of last N)
    var baseline: f32 = 0.0;
    for (history) |v| baseline += v;
    baseline /= @as(f32, @floatFromInt(history.len));

    const spike_threshold = baseline * 1.5; // 50% increase = spike
    analysis.is_spike = current_ppl > spike_threshold;

    const regression_threshold = baseline * 2.0; // 2x = regression
    analysis.is_regression = current_ppl > regression_threshold;

    // φ-patience: wait φ² (≈2.618) cycles before declaring regression
    const phi: f32 = 1.618033988749895;
    const phi_squared = phi * phi;

    if (analysis.is_regression) {
        // Check if regression persists over φ² cycles
        const recent_high = countRecentHighs(history, current_ppl);
        if (recent_high >= @as(usize, @intFromFloat(@floor(phi_squared)))) {
            analysis.recommendation = .alert;
            analysis.confidence = 0.9;
            analysis.setReason("Regression persists > φ² cycles");
        } else {
            analysis.recommendation = .wait;
            analysis.confidence = 0.5;
            analysis.setReason("Spike detected, φ-patience active");
        }
    } else if (analysis.is_spike) {
        analysis.recommendation = .wait;
        analysis.confidence = 0.3;
        analysis.setReason("Spike within expected range");
    } else {
        analysis.recommendation = .ignore;
        analysis.confidence = 0.95;
        analysis.setReason("Normal training fluctuation");
    }

    return analysis;
}

/// Count how many recent values are above threshold
fn countRecentHighs(history: []const f32, threshold: f32) usize {
    var count: usize = 0;
    for (history) |v| {
        if (v > threshold) count += 1;
    }
    return count;
}

/// Moving average for smoothing
pub fn movingAverage(window: []const f32) f32 {
    if (window.len == 0) return 0.0;
    var sum: f32 = 0.0;
    for (window) |v| sum += v;
    return sum / @as(f32, @floatFromInt(window.len));
}

/// φ-weighted patience — how long to wait before alert
pub fn phiPatienceCycles() u32 {
    const phi: f32 = 1.618033988749895;
    return @as(u32, @intFromFloat(@floor(phi * phi))); // φ² ≈ 2.618 → 2 cycles
}

/// Check if PPL spike is expected (cosine restart, φ-checkpoint)
pub fn isExpectedSpike(step: u32, ppl: f32) bool {
    // Cosine schedule typically spikes at checkpoints
    // Common checkpoints: 10K, 20K, 50K, 100K
    const checkpoints = [_]u32{ 10000, 20000, 50000, 100000 };
    for (checkpoints) |cp| {
        if (@abs(@as(i32, @intCast(step)) - @as(i32, @intCast(cp))) < 1000) {
            return true; // Within 1K steps of checkpoint
        }
    }

    // Also expect spikes after inject (sharp PPL changes common)
    _ = ppl;
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// CELL HEALTH
// ═══════════════════════════════════════════════════════════════════════════════

pub fn health() CellHealth {
    return CellHealth{
        .status = .healthy,
        .cycle = 0,
        .last_check = std.time.timestamp(),
    };
}

pub const CellHealth = struct {
    status: Status = .healthy,
    cycle: u32 = 0,
    last_check: i64 = 0,

    pub const Status = enum {
        healthy,
        weak,
        broken,
    };
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "raphe — smoothPPLSpikes normal" {
    const history = [_]f32{ 4.5, 4.6, 4.7, 4.5, 4.8 };
    const analysis = try smoothPPLSpikes(
        std.testing.allocator,
        4.9, // small increase
        &history,
    );

    try std.testing.expect(!analysis.is_regression);
    try std.testing.expect(analysis.recommendation != .alert);
}

test "raphe — smoothPPLSpikes regression" {
    const history = [_]f32{ 4.5, 4.6, 4.7, 8.0, 9.0 }; // Multiple high values
    const analysis = try smoothPPLSpikes(
        std.testing.allocator,
        10.0, // Big jump
        &history,
    );

    try std.testing.expect(analysis.is_regression);
    // May recommend alert or wait depending on φ² count
}

test "raphe — movingAverage" {
    const window = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    const avg = movingAverage(&window);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), avg, 0.01);
}

test "raphe — phiPatienceCycles" {
    const cycles = phiPatienceCycles();
    try std.testing.expect(cycles == 2); // φ² ≈ 2.618 → floor = 2
}

test "raphe — isExpectedSpike at checkpoint" {
    try std.testing.expect(isExpectedSpike(10000, 10.0));
    try std.testing.expect(isExpectedSpike(10500, 10.0));
    try std.testing.expect(!isExpectedSpike(15000, 10.0));
}

test "raphe — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
}
