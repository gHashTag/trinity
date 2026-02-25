//! φ Gate — Sacred Math Filter for PHI LOOP
//! Every generated code must pass through the φ Gate before acceptance
//! φ² + 1/φ² = 3 — Trinity Identity validation

const std = @import("std");
const phi_types = @import("phi_types.zig");

/// φ Gate — the sacred filter between generation and acceptance
pub const PhiGate = struct {
    allocator: std.mem.Allocator,
    pas_score: f64,
    confidence: f32,
    sona_q_value: f64,
    trinity_verified: bool,
    phi_weighted: bool,
    error_count: u32,
    warning_count: u32,
    timestamp: i64,

    /// Initialize a new φ Gate
    pub fn init(allocator: std.mem.Allocator) PhiGate {
        return PhiGate{
            .allocator = allocator,
            .pas_score = 0.0,
            .confidence = 0.0,
            .sona_q_value = 0.0,
            .trinity_verified = phi_types.Sacred.trinityIdentity(),
            .phi_weighted = false,
            .error_count = 0,
            .warning_count = 0,
            .timestamp = std.time.timestamp(),
        };
    }

    /// Set PAS sacred score
    pub fn setPasScore(self: *PhiGate, score: f64) void {
        self.pas_score = @max(0.0, @min(score, 1.0));
    }

    /// Set pattern confidence
    pub fn setConfidence(self: *PhiGate, conf: f32) void {
        self.confidence = @max(0.0, @min(conf, 1.0));
    }

    /// Set SONA Q-value
    pub fn setSonaQValue(self: *PhiGate, q_value: f64) void {
        self.sona_q_value = @max(0.0, @min(q_value, 1.0));
    }

    /// Add error count
    pub fn addErrors(self: *PhiGate, count: u32) void {
        self.error_count += count;
    }

    /// Add warning count
    pub fn addWarnings(self: *PhiGate, count: u32) void {
        self.warning_count += count;
    }

    /// Main validation — does the code pass the φ Gate?
    pub fn passes(self: *const PhiGate) bool {
        // Sacred threshold check
        if (self.pas_score < phi_types.Sacred.SACRED_THRESHOLD) {
            return false;
        }

        // Trinity identity must hold
        if (!self.trinity_verified) {
            return false;
        }

        // High confidence required
        if (self.confidence < 0.95) {
            return false;
        }

        // SONA learning must be positive
        if (self.sona_q_value < 0.5) {
            return false;
        }

        // Error count must be minimal
        if (self.error_count > 0) {
            return false;
        }

        // Warnings allowed but penalized
        if (self.warning_count > 5) {
            return false;
        }

        return true;
    }

    /// Calculate overall gate score (0-1)
    pub fn gateScore(self: *const PhiGate) f64 {
        var score: f64 = 0.0;

        // PAS score: 40% weight
        score += self.pas_score * 0.4;

        // Confidence: 30% weight
        score += @as(f64, self.confidence) * 0.3;

        // SONA Q-value: 20% weight
        score += self.sona_q_value * 0.2;

        // Trinity identity: 10% weight
        if (self.trinity_verified) {
            score += 0.1;
        }

        // Apply μ penalty for errors/warnings
        const penalty = phi_types.Sacred.muPenalty(self.error_count + self.warning_count);
        score -= penalty;

        return @max(0.0, @min(score, 1.0));
    }

    /// Calculate φ-weighted score
    pub fn phiWeightedScore(self: *const PhiGate) f64 {
        const base = self.gateScore();
        return phi_types.Sacred.phiWeighted(base);
    }

    /// Get human-readable status
    pub fn status(self: *const PhiGate) GateStatus {
        if (self.passes()) {
            return .passed;
        }

        // Determine failure reason by checking thresholds
        if (self.pas_score < phi_types.Sacred.SACRED_THRESHOLD) {
            return .failed_pas;
        }
        if (self.confidence < 0.95) {
            return .failed_confidence;
        }
        if (self.sona_q_value < 0.5) {
            return .failed_sona;
        }
        return .failed_trinity;
    }

    /// Get detailed failure message
    pub fn failureMessage(self: *const PhiGate, allocator: std.mem.Allocator) ![]const u8 {
        const gate_status = self.status();

        if (gate_status == .passed) {
            return try std.fmt.allocPrint(allocator, "φ Gate PASSED (score: {d:.3})", .{self.gateScore()});
        }

        const reason = switch (gate_status) {
            .failed_pas => "PAS score below threshold",
            .failed_confidence => "Confidence below 95%",
            .failed_sona => "SONA Q-value too low",
            .failed_trinity => "Trinity identity not verified",
            .passed => unreachable,
        };

        return try std.fmt.allocPrint(allocator,
            "φ Gate FAILED: {s} (PAS: {d:.3}, Conf: {d:.3}, SONA: {d:.3})",
            .{ reason, self.pas_score, self.confidence, self.sona_q_value }
        );
    }

    /// Apply φ-weighted boost to scores
    pub fn applyPhiWeight(self: *PhiGate) void {
        if (!self.phi_weighted) {
            self.pas_score = phi_types.Sacred.phiWeighted(self.pas_score);
            self.pas_score = @min(self.pas_score, 1.0); // Clamp to 1.0
            self.phi_weighted = true;
        }
    }

    /// Reset the gate for new validation
    pub fn reset(self: *PhiGate) void {
        self.pas_score = 0.0;
        self.confidence = 0.0;
        self.sona_q_value = 0.0;
        self.error_count = 0;
        self.warning_count = 0;
        self.phi_weighted = false;
        self.timestamp = std.time.timestamp();
    }

    /// Export gate state as JSON (for dashboard)
    pub fn toJson(self: *const PhiGate, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator,
            "{{\"pas_score\":{d:.4},\"confidence\":{d:.4},\"sona_q_value\":{d:.4},\"trinity_verified\":{s},\"gate_score\":{d:.4},\"phi_weighted_score\":{d:.4},\"error_count\":{d},\"warning_count\":{d},\"status\":\"{s}\",\"timestamp\":{d}}}",
        .{
            self.pas_score,
            self.confidence,
            self.sona_q_value,
            if (self.trinity_verified) "true" else "false",
            self.gateScore(),
            self.phiWeightedScore(),
            self.error_count,
            self.warning_count,
            @tagName(self.status()),
            self.timestamp,
        });
    }
};

/// Gate status enum
pub const GateStatus = enum {
    passed,             // All checks passed
    failed_pas,         // PAS score too low
    failed_confidence,  // Confidence too low
    failed_sona,        // SONA Q-value too low
    failed_trinity,     // Trinity identity failed
};

/// Batch validator for multiple gates
pub const BatchValidator = struct {
    allocator: std.mem.Allocator,
    gates: std.ArrayListUnmanaged(PhiGate),

    pub fn init(allocator: std.mem.Allocator) BatchValidator {
        return BatchValidator{
            .allocator = allocator,
            .gates = .{},
        };
    }

    pub fn deinit(self: *BatchValidator) void {
        self.gates.deinit(self.allocator);
    }

    /// Add a new gate to batch
    pub fn addGate(self: *BatchValidator, gate: PhiGate) !void {
        try self.gates.append(self.allocator, gate);
    }

    /// Validate all gates
    pub fn validateAll(self: *const BatchValidator) BatchResult {
        var passed: u32 = 0;
        var failed: u32 = 0;
        var total_score: f64 = 0.0;

        for (self.gates.items) |gate| {
            if (gate.passes()) {
                passed += 1;
            } else {
                failed += 1;
            }
            total_score += gate.gateScore();
        }

        const avg_score = if (self.gates.items.len > 0)
            total_score / @as(f64, @floatFromInt(self.gates.items.len))
        else
            0.0;

        return BatchResult{
            .total = @intCast(self.gates.items.len),
            .passed = passed,
            .failed = failed,
            .average_score = avg_score,
            .success_rate = if (self.gates.items.len > 0)
                @as(f32, @floatFromInt(passed)) / @as(f32, @floatFromInt(self.gates.items.len))
            else
                0.0,
        };
    }
};

/// Batch validation result
pub const BatchResult = struct {
    total: u32,
    passed: u32,
    failed: u32,
    average_score: f64,
    success_rate: f32,

    pub fn allPassed(self: *const BatchResult) bool {
        return self.failed == 0;
    }
};

// Tests
test "PhiGate initialization" {
    const allocator = std.testing.allocator;
    const gate = PhiGate.init(allocator);

    try std.testing.expectEqual(@as(f64, 0.0), gate.pas_score);
    try std.testing.expectEqual(@as(f32, 0.0), gate.confidence);
    try std.testing.expectEqual(@as(u32, 0), gate.error_count);
    try std.testing.expect(gate.trinity_verified);
}

test "PhiGate passes with good scores" {
    const allocator = std.testing.allocator;
    var gate = PhiGate.init(allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    try std.testing.expect(gate.passes());
    try std.testing.expectEqual(GateStatus.passed, gate.status());
}

test "PhiGate fails with low PAS score" {
    const allocator = std.testing.allocator;
    var gate = PhiGate.init(allocator);

    gate.setPasScore(0.80);  // Below SACRED_THRESHOLD
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    try std.testing.expect(!gate.passes());
    try std.testing.expectEqual(GateStatus.failed_pas, gate.status());
}

test "PhiGate fails with low confidence" {
    const allocator = std.testing.allocator;
    var gate = PhiGate.init(allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.90);  // Below 0.95
    gate.setSonaQValue(0.8);

    try std.testing.expect(!gate.passes());
    try std.testing.expectEqual(GateStatus.failed_confidence, gate.status());
}

test "PhiGate gateScore calculation" {
    const allocator = std.testing.allocator;
    var gate = PhiGate.init(allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);

    const score = gate.gateScore();
    try std.testing.expect(score > 0.8);
}

test "PhiGate phiWeightedScore" {
    const allocator = std.testing.allocator;
    var gate = PhiGate.init(allocator);

    gate.setPasScore(0.6);
    gate.setConfidence(0.7);
    gate.setSonaQValue(0.6);

    const before = gate.gateScore();
    gate.applyPhiWeight();
    const after = gate.phiWeightedScore();

    try std.testing.expect(after > before);
}

test "PhiGate failureMessage" {
    const allocator = std.testing.allocator;
    var gate = PhiGate.init(allocator);

    gate.setPasScore(0.80);

    const msg = try gate.failureMessage(allocator);
    defer allocator.free(msg);

    try std.testing.expect(std.mem.indexOf(u8, msg, "FAILED") != null);
}

test "BatchValidator" {
    const allocator = std.testing.allocator;
    var batch = BatchValidator.init(allocator);
    defer batch.deinit();

    var gate1 = PhiGate.init(allocator);
    gate1.setPasScore(0.96);
    gate1.setConfidence(0.97);
    gate1.setSonaQValue(0.8);
    try batch.addGate(gate1);

    var gate2 = PhiGate.init(allocator);
    gate2.setPasScore(0.80);
    gate2.setConfidence(0.97);
    gate2.setSonaQValue(0.8);
    try batch.addGate(gate2);

    const result = batch.validateAll();
    try std.testing.expectEqual(@as(u32, 2), result.total);
    try std.testing.expectEqual(@as(u32, 1), result.passed);
    try std.testing.expectEqual(@as(u32, 1), result.failed);
    try std.testing.expect(!result.allPassed());
}

test "PhiGate reset" {
    const allocator = std.testing.allocator;
    var gate = PhiGate.init(allocator);

    gate.setPasScore(0.96);
    gate.setConfidence(0.97);
    gate.setSonaQValue(0.8);
    gate.addErrors(5);
    gate.addWarnings(3);

    gate.reset();

    try std.testing.expectEqual(@as(f64, 0.0), gate.pas_score);
    try std.testing.expectEqual(@as(f32, 0.0), gate.confidence);
    try std.testing.expectEqual(@as(u32, 0), gate.error_count);
    try std.testing.expectEqual(@as(u32, 0), gate.warning_count);
}
