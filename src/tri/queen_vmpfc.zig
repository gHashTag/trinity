// @origin(manual) @regen(pending)
// ═══════════════════════════════════════════════════════════════════════════════
// VENTROMEDIAL PREFRONTAL CORTEX (VMPFC) — Value Assessment
// ═══════════════════════════════════════════════════════════════════════════════
// Neuro: Value-based decision making, reward prediction, cost-benefit analysis
// Trinity: "Is this action worth it?" — ROI scoring, φ-weighted assessment
//
// φ² + 1/φ² = 3 = TRINITY
// ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;
const qt = @import("queen_types.zig");
const thalamus = @import("thalamus.zig");

// ═══════════════════════════════════════════════════════════════════════════════
// VALUE ASSESSMENT — "Is this action worth it?"
// ═══════════════════════════════════════════════════════════════════════════════

pub const ValueAssessment = struct {
    roi: f32 = 0.0, // PPL improvement per compute cost
    confidence: f32 = 0.0, // 0-1
    recommendation: Recommendation = .wait,
    reason: [128]u8 = undefined,
    reason_len: usize = 0,

    pub fn reasonStr(self: *const ValueAssessment) []const u8 {
        return self.reason[0..self.reason_len];
    }

    fn setReason(self: *ValueAssessment, text: []const u8) void {
        const len = @min(text.len, self.reason.len);
        @memcpy(self.reason[0..len], text[0..len]);
        self.reason_len = len;
    }
};

pub const Recommendation = enum {
    execute, // Do it now
    wait, // Collect more data
    skip, // Not worth it
};

/// Assess farm action — PPL improvement vs compute cost
pub fn assessFarmAction(
    allocator: Allocator,
    action: FarmAction,
    current_ppl: f32,
) !ValueAssessment {
    var assessment = ValueAssessment{};

    // Get farm status for context
    const farm_status = try thalamus.getFarmStatus(allocator);

    switch (action) {
        .inject => {
            // Inject: high ROI if best_ppl > current_ppl + threshold
            const ppl_gap = farm_status.best_ppl - current_ppl;
            if (ppl_gap > 1.0) {
                assessment.roi = ppl_gap * 10.0; // PPL improvement × 10
                assessment.confidence = 0.8;
                assessment.recommendation = .execute;
                assessment.setReason("PPL gap > 1.0, inject from best");
            } else if (ppl_gap > 0.3) {
                assessment.roi = ppl_gap * 5.0;
                assessment.confidence = 0.5;
                assessment.recommendation = .wait;
                assessment.setReason("PPL gap small, wait for more data");
            } else {
                assessment.roi = 0.0;
                assessment.confidence = 0.9;
                assessment.recommendation = .skip;
                assessment.setReason("PPL gap too small, skip inject");
            }
        },
        .recycle => {
            // Recycle: ROI based on stale/crashed count
            const problem_count = farm_status.stale_count + farm_status.crashed;
            if (problem_count > 5) {
                assessment.roi = @as(f32, @floatFromInt(problem_count)) * 2.0;
                assessment.confidence = 0.9;
                assessment.recommendation = .execute;
                assessment.setReason("Many stale/crashed workers, recycle now");
            } else if (problem_count > 2) {
                assessment.roi = @as(f32, @floatFromInt(problem_count));
                assessment.confidence = 0.6;
                assessment.recommendation = .wait;
                assessment.setReason("Some problems, consider recycling");
            } else {
                assessment.roi = 0.0;
                assessment.confidence = 0.7;
                assessment.recommendation = .skip;
                assessment.setReason("Farm healthy, skip recycle");
            }
        },
        .evolve => {
            // Evolve: always high ROI for exploration
            assessment.roi = 5.0; // Base exploration value
            assessment.confidence = 0.7;
            assessment.recommendation = .execute;
            assessment.setReason("Evolution drives long-term improvement");
        },
    }

    return assessment;
}

pub const FarmAction = enum {
    inject,
    recycle,
    evolve,
};

/// φ-weighted scoring — sacred numbers bias
pub fn phiWeightedScore(base_score: f32) f32 {
    const phi: f32 = 1.618033988749895;
    return base_score * phi;
}

/// Cell health check for tri cell status
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

test "vmpfc — assessFarmAction inject with gap" {
    const assessment = try assessFarmAction(
        std.testing.allocator,
        .inject,
        5.0, // current_ppl
    );
    // Note: assessment.reason is a fixed-size array, not heap-allocated
    // No need to free it

    // Should recommend something (depends on farm state)
    try std.testing.expect(assessment.confidence >= 0.0);
    try std.testing.expect(assessment.confidence <= 1.0);
}

test "vmpfc — phiWeightedScore" {
    const score = phiWeightedScore(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.618), score, 0.01);
}

test "vmpfc — health returns healthy" {
    const h = health();
    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expect(h.last_check > 0);
}

test "vmpfc — ValueAssessment setReason truncates" {
    var assessment = ValueAssessment{};
    const long_text = "This is a very long reason that should be truncated to fit in the 128 byte array provided for the reason field in ValueAssessment";
    assessment.setReason(long_text);

    try std.testing.expect(assessment.reason_len <= 128);
    try std.testing.expect(assessment.reasonStr().len > 0);
}

test "vmpfc — assessFarmAction recycle decision" {
    const assessment = try assessFarmAction(
        std.testing.allocator,
        .recycle,
        10.0,
    );
    // Note: assessment.reason is a fixed-size array, not heap-allocated

    // Should return a valid assessment
    try std.testing.expect(assessment.roi >= 0.0);
    try std.testing.expect(assessment.confidence >= 0.0);
    try std.testing.expect(assessment.confidence <= 1.0);
}

test "vmpfc — assessFarmAction evolve always executes" {
    const assessment = try assessFarmAction(
        std.testing.allocator,
        .evolve,
        5.0,
    );
    // Note: assessment.reason is a fixed-size array, not heap-allocated

    try std.testing.expectEqual(Recommendation.execute, assessment.recommendation);
    try std.testing.expect(assessment.roi > 0.0);
}

test "vmpfc — Recommendation enum coverage" {
    const recommendations = [_]Recommendation{ .execute, .wait, .skip };
    for (recommendations) |rec| {
        _ = rec; // Verify all enum values exist
    }
}

test "vmpfc — phiWeightedScore constants" {
    const phi: f32 = 1.618033988749895;

    // Score of 0 should stay 0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), phiWeightedScore(0.0), 0.001);

    // Score of 1 should be phi
    try std.testing.expectApproxEqAbs(phi, phiWeightedScore(1.0), 0.001);

    // Score of 2 should be 2*phi
    try std.testing.expectApproxEqAbs(2.0 * phi, phiWeightedScore(2.0), 0.001);
}

test "vmpfc — ValueAssessment default values" {
    const assessment = ValueAssessment{};
    try std.testing.expectEqual(@as(f32, 0.0), assessment.roi);
    try std.testing.expectEqual(@as(f32, 0.0), assessment.confidence);
    try std.testing.expectEqual(Recommendation.wait, assessment.recommendation);
    try std.testing.expectEqual(@as(usize, 0), assessment.reason_len);
}

test "vmpfc — ValueAssessment reasonStr empty" {
    var assessment = ValueAssessment{};
    assessment.setReason("");
    try std.testing.expectEqual(@as(usize, 0), assessment.reason_len);
    try std.testing.expectEqual(@as(usize, 0), assessment.reasonStr().len);
}

test "vmpfc — ValueAssessment reasonStr returns slice" {
    var assessment = ValueAssessment{};
    assessment.setReason("test reason");
    try std.testing.expectEqualStrings("test reason", assessment.reasonStr());
}

test "vmpfc — FarmAction enum coverage" {
    const actions = [_]FarmAction{ .inject, .recycle, .evolve };
    for (actions) |action| {
        _ = action; // Verify all enum values exist
    }
}

test "vmpfc — CellHealth struct defaults" {
    const cell_health = CellHealth{};
    try std.testing.expectEqual(CellHealth.Status.healthy, cell_health.status);
    try std.testing.expectEqual(@as(u32, 0), cell_health.cycle);
    try std.testing.expectEqual(@as(i64, 0), cell_health.last_check);
}

test "vmpfc — CellHealth Status enum values" {
    const statuses = [_]CellHealth.Status{ .healthy, .weak, .broken };
    for (statuses) |s| {
        _ = s; // Verify all enum values exist
    }
}

test "vmpfc — phiWeightedScore with negative" {
    const result = phiWeightedScore(-1.0);
    try std.testing.expect(result < 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, -1.618), result, 0.01);
}

test "vmpfc — phiWeightedScore large values" {
    const result = phiWeightedScore(100.0);
    try std.testing.expect(result > 100.0);
    try std.testing.expectApproxEqAbs(@as(f32, 161.8), result, 0.1);
}

test "vmpfc — assessFarmAction all actions return valid confidence" {
    const actions = [_]FarmAction{ .inject, .recycle, .evolve };
    for (actions) |action| {
        const assessment = try assessFarmAction(std.testing.allocator, action, 5.0);
        try std.testing.expect(assessment.confidence >= 0.0);
        try std.testing.expect(assessment.confidence <= 1.0);
    }
}

test "vmpfc — assessFarmAction reason is set" {
    const actions = [_]FarmAction{ .inject, .recycle, .evolve };
    for (actions) |action| {
        const assessment = try assessFarmAction(std.testing.allocator, action, 5.0);
        try std.testing.expect(assessment.reason_len > 0);
        try std.testing.expect(assessment.reasonStr().len > 0);
    }
}

test "vmpfc — assessFarmAction ROI non-negative" {
    const actions = [_]FarmAction{ .inject, .recycle, .evolve };
    for (actions) |action| {
        const assessment = try assessFarmAction(std.testing.allocator, action, 5.0);
        try std.testing.expect(assessment.roi >= 0.0);
    }
}

test "vmpfc — ValueAssessment setReason with exact fit" {
    var assessment = ValueAssessment{};
    const text = "a" ** 127; // Exactly fits
    assessment.setReason(text);
    try std.testing.expectEqual(@as(usize, 127), assessment.reason_len);
}

test "vmpfc — ValueAssessment setReason truncation" {
    var assessment = ValueAssessment{};
    const text = "a" ** 200; // Should be truncated
    assessment.setReason(text);
    try std.testing.expectEqual(@as(usize, 128), assessment.reason_len);
}

test "vmpfc — Recommendation all values" {
    const recommendations = [_]Recommendation{
        .execute, .wait, .skip,
    };

    for (recommendations) |r| {
        _ = r; // Verify all recommendations exist
    }
}

test "vmpfc — ValueAssessment with execute recommendation" {
    const assessment = ValueAssessment{
        .roi = 10.0,
        .confidence = 0.9,
        .recommendation = .execute,
    };

    try std.testing.expectEqual(Recommendation.execute, assessment.recommendation);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), assessment.roi, 0.01);
}

test "vmpfc — ValueAssessment with skip recommendation" {
    const assessment = ValueAssessment{
        .roi = 0.0,
        .confidence = 0.95,
        .recommendation = .skip,
    };

    try std.testing.expectEqual(Recommendation.skip, assessment.recommendation);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), assessment.roi, 0.01);
}

test "vmpfc — FarmAction all values" {
    const actions = [_]FarmAction{
        .inject, .recycle, .evolve,
    };

    for (actions) |a| {
        _ = a; // Verify all actions exist
    }
}

test "vmpfc — phiWeightedScore with zero" {
    const score = phiWeightedScore(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), score, 0.01);
}

test "vmpfc — phiWeightedScore edge cases" {
    // Zero
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), phiWeightedScore(0.0), 0.01);

    // Small positive
    const small = phiWeightedScore(0.1);
    try std.testing.expect(small > 0.0);

    // Large value
    const large = phiWeightedScore(100.0);
    try std.testing.expect(large > 50.0); // Should be significantly higher
}

test "vmpfc — CellHealth with broken status" {
    const h = CellHealth{ .status = .broken };

    try std.testing.expectEqual(CellHealth.Status.broken, h.status);
}

test "vmpfc — CellHealth last_check timestamp" {
    const h = CellHealth{};

    try std.testing.expectEqual(@as(i64, 0), h.last_check);
}

test "vmpfc — CellHealth from health() has timestamp" {
    const h = health();

    try std.testing.expect(h.last_check > 0);
}

test "vmpfc — ValueAssessment setReason empty" {
    var assessment = ValueAssessment{};
    const empty = "";

    assessment.setReason(empty);

    try std.testing.expectEqual(@as(usize, 0), assessment.reason_len);
}

test "vmpfc — ValueAssessment setReason with special chars" {
    var assessment = ValueAssessment{};
    const text = "Test: φ² + 1/φ² = 3";

    assessment.setReason(text);

    try std.testing.expectEqualStrings(text, assessment.reasonStr());
}
