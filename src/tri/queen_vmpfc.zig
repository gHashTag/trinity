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

// ═══════════════════════════════════════════════════════════════════════════════
// REAL FUNCTION TESTS — Testing actual computation and logic
// ═══════════════════════════════════════════════════════════════════════════════

test "vmpfc — phiWeightedScore calculates phi multiplication correctly" {
    const phi: f32 = 1.618033988749895;

    // Test various inputs produce expected phi-multiplied outputs
    const result_1 = phiWeightedScore(1.0);
    try std.testing.expectApproxEqAbs(phi, result_1, 0.001);

    const result_5 = phiWeightedScore(5.0);
    try std.testing.expectApproxEqAbs(5.0 * phi, result_5, 0.001);

    const result_10 = phiWeightedScore(10.0);
    try std.testing.expectApproxEqAbs(10.0 * phi, result_10, 0.001);
}

test "vmpfc — phiWeightedScore handles fractional inputs" {
    const phi: f32 = 1.618033988749895;

    // Test 0.5 * phi
    const result = phiWeightedScore(0.5);
    try std.testing.expectApproxEqAbs(0.5 * phi, result, 0.001);

    // Verify result is between 0 and phi
    try std.testing.expect(result > 0.0);
    try std.testing.expect(result < phi);
}

test "vmpfc — health returns valid timestamp" {
    const h = health();
    const now = std.time.timestamp();

    // Timestamp should be recent (within last second)
    try std.testing.expect(h.last_check > 0);
    try std.testing.expect(h.last_check <= now);
    try std.testing.expect(now - h.last_check <= 1);
}

test "vmpfc — health returns healthy status with zero cycle" {
    const h = health();

    try std.testing.expectEqual(CellHealth.Status.healthy, h.status);
    try std.testing.expectEqual(@as(u32, 0), h.cycle);
}

test "vmpfc — ValueAssessment setReason and reasonStr roundtrip" {
    var assessment = ValueAssessment{};

    const original = "Farm needs recycling due to stale workers";
    assessment.setReason(original);

    try std.testing.expectEqualStrings(original, assessment.reasonStr());
    try std.testing.expectEqual(original.len, assessment.reason_len);
}

test "vmpfc — ValueAssessment setReason preserves UTF-8 bytes" {
    var assessment = ValueAssessment{};

    // UTF-8 string with multi-byte characters
    const text = "φ² + 1/φ² = 3 — Trinity identity";
    assessment.setReason(text);

    try std.testing.expectEqualStrings(text, assessment.reasonStr());
    try std.testing.expectEqual(text.len, assessment.reason_len);
}

test "vmpfc — ValueAssessment setReason handles multibyte truncation" {
    var assessment = ValueAssessment{};

    // Long UTF-8 string that will be truncated
    const long_text = "φ" ** 100; // 100 phi symbols (each 2 bytes in UTF-8)
    assessment.setReason(long_text);

    // Should truncate to 128 bytes (64 phi symbols)
    try std.testing.expectEqual(@as(usize, 128), assessment.reason_len);
    try std.testing.expect(assessment.reasonStr().len == 128);
}

test "vmpfc — assessFarmAction evolve has fixed high ROI" {
    const assessment = try assessFarmAction(
        std.testing.allocator,
        .evolve,
        999.0, // PPL shouldn't matter for evolve
    );

    // Evolve always has ROI of 5.0
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), assessment.roi, 0.01);
    try std.testing.expectEqual(Recommendation.execute, assessment.recommendation);
}

test "vmpfc — assessFarmAction inject confidence ranges correctly" {
    // Test with different PPL values to check confidence calculation
    const assessment_low = try assessFarmAction(std.testing.allocator, .inject, 100.0);
    const assessment_high = try assessFarmAction(std.testing.allocator, .inject, 1.0);

    // Confidence should be in valid range regardless of PPL
    try std.testing.expect(assessment_low.confidence >= 0.0);
    try std.testing.expect(assessment_low.confidence <= 1.0);
    try std.testing.expect(assessment_high.confidence >= 0.0);
    try std.testing.expect(assessment_high.confidence <= 1.0);
}
