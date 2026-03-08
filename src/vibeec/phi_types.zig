//! PHI LOOP Types — 999 Links of Cosmic Consciousness Gene
//! Types for the main improvement loop: VIBEE → Agent MU → Symbolic AI → φ Gate

const std = @import("std");

/// Sacred constants — the bridge between spirit and matter
pub const Sacred = struct {
    /// Golden ratio: φ = (1 + √5) / 2
    pub const PHI = 1.618033988749895;

    /// Sacred mu: μ = 0.0382
    pub const MU = 0.0382;

    /// Sacred threshold for quality gates
    pub const SACRED_THRESHOLD = 0.95;

    /// Trinity Identity: φ² + 1/φ² = 3
    pub fn trinityIdentity() bool {
        const phi_squared = PHI * PHI;
        const inverse_phi_squared = 1.0 / phi_squared;
        return @abs(phi_squared + inverse_phi_squared - 3.0) < 0.0001;
    }

    /// Calculate φ-weighted score
    pub fn phiWeighted(score: f64) f64 {
        return PHI * score;
    }

    /// Calculate μ-weighted penalty
    pub fn muPenalty(error_count: u32) f64 {
        return @as(f64, @floatFromInt(error_count)) * MU;
    }
};

/// Link result from one PHI LOOP iteration
pub const LinkResult = struct {
    link_number: u32, // Current link (1-999)
    pas_score: f64, // PAS sacred scoring
    trinity_identity: bool, // φ² + 1/φ² = 3 verified
    confidence: f32, // Pattern confidence
    sona_q_value: f64, // SONA learning Q-value
    next_action: NextAction, // What to do next
    generation_time_ms: u64, // Time taken for generation
    validation_time_ms: u64, // Time taken for validation

    /// Check if this link passed the φ Gate
    pub fn passedPhiGate(self: *const LinkResult) bool {
        if (self.pas_score < Sacred.SACRED_THRESHOLD) return false;
        if (!self.trinity_identity) return false;
        if (self.confidence < 0.95) return false;
        return true;
    }

    /// Calculate overall quality score
    pub fn qualityScore(self: *const LinkResult) f64 {
        var score = self.pas_score * 0.4;
        score += @as(f64, self.confidence) * 0.3;
        score += self.sona_q_value * 0.2;
        score += if (self.trinity_identity) @as(f64, 0.1) else 0.0;
        return score;
    }
};

/// Action to take after a link completes
pub const NextAction = enum {
    proceed, // Proceed to next link
    retry, // Retry current link with fixes
    skip, // Skip this spec
    complete, // All 999 links complete
    circuit_break, // Too many failures, stop
};

/// Generated code output from VIBEE
pub const GeneratedCode = struct {
    code: []const u8,
    output_path: []const u8,
    language: []const u8,
    pattern_id: u64,
    timestamp: i64,

    /// Calculate simple quality metrics
    pub fn metrics(self: *const GeneratedCode) CodeMetrics {
        const line_count = std.mem.count(u8, self.code, "\n");
        const has_comments = std.mem.indexOf(u8, self.code, "//") != null;
        const has_tests = std.mem.indexOf(u8, self.code, "test") != null;

        return CodeMetrics{
            .line_count = @intCast(line_count),
            .has_comments = has_comments,
            .has_tests = has_tests,
            .char_count = self.code.len,
        };
    }
};

/// Basic code metrics
pub const CodeMetrics = struct {
    line_count: usize,
    has_comments: bool,
    has_tests: bool,
    char_count: usize,

    /// Calculate basic completeness score
    pub fn completeness(self: *const CodeMetrics) f32 {
        var score: f32 = 0.0;
        if (self.line_count > 0) score += 0.3;
        if (self.has_comments) score += 0.2;
        if (self.has_tests) score += 0.3;
        if (self.char_count > 100) score += 0.2;
        return score;
    }
};

/// Validation result from Agent MU
pub const ValidationResult = struct {
    pattern_id: u64,
    passed: bool,
    errors: []const Error,
    warnings: []const Warning,
    confidence: f32,

    pub const Error = struct {
        message: []const u8,
        line: ?usize,
        code: []const u8,
    };

    pub const Warning = struct {
        message: []const u8,
        line: ?usize,
        code: []const u8,
    };

    /// Calculate severity score (0 = clean, 1 = critical)
    pub fn severity(self: *const ValidationResult) f32 {
        const error_weight = 0.1;
        const warning_weight = 0.02;
        const total = @as(f32, @floatFromInt(self.errors.len)) * error_weight +
            @as(f32, @floatFromInt(self.warnings.len)) * warning_weight;
        return @min(total, 1.0);
    }
};

/// φ Gate filter — sacred math validation
pub const PhiGate = struct {
    pas_score: f64,
    trinity_identity: bool,
    phi_weighted: bool,
    sona_q_value: f64,
    confidence: f32,
    timestamp: i64,

    /// Create a new φ Gate
    pub fn init() PhiGate {
        return PhiGate{
            .pas_score = 0.0,
            .trinity_identity = Sacred.trinityIdentity(),
            .phi_weighted = false,
            .sona_q_value = 0.0,
            .confidence = 0.0,
            .timestamp = std.time.timestamp(),
        };
    }

    /// Check if the gate passes
    pub fn passes(self: *const PhiGate) bool {
        if (self.pas_score < Sacred.SACRED_THRESHOLD) return false;
        if (!self.trinity_identity) return false;
        if (self.confidence < 0.95) return false;
        if (self.sona_q_value < 0.5) return false;
        return true;
    }

    /// Calculate gate score (0-1)
    pub fn gateScore(self: *const PhiGate) f64 {
        var score = self.pas_score * 0.4;
        score += @as(f64, @floatFromInt(self.confidence)) * 0.3;
        score += self.sona_q_value * 0.2;
        score += if (self.trinity_identity) @as(f64, 0.1) else 0.0;
        return @min(score, 1.0);
    }

    /// Get human-readable status
    pub fn status(self: *const PhiGate) []const u8 {
        if (self.passes()) return "PASSED";
        if (self.pas_score < Sacred.SACRED_THRESHOLD) return "FAILED_PAS";
        if (!self.trinity_identity) return "FAILED_TRINITY";
        if (self.confidence < 0.95) return "FAILED_CONFIDENCE";
        if (self.sona_q_value < 0.5) return "FAILED_SONA";
        return "UNKNOWN";
    }
};

/// Task decomposition for φ Decompose step
pub const TaskDecomposition = struct {
    name: []const u8,
    description: []const u8,
    complexity: Complexity,
    estimated_lines: usize,
    dependencies: []const []const u8,

    pub const Complexity = enum {
        trivial, // < 50 lines
        simple, // 50-200 lines
        moderate, // 200-500 lines
        complex, // 500-1000 lines
        critical, // > 1000 lines
    };

    /// Calculate φ-weighted priority
    pub fn priority(self: *const TaskDecomposition) f64 {
        const base_score: f64 = switch (self.complexity) {
            .trivial => 0.2,
            .simple => 0.4,
            .moderate => 0.6,
            .complex => 0.8,
            .critical => 1.0,
        };
        return Sacred.phiWeighted(base_score);
    }
};

/// SONA episode for learning
pub const SonaEpisode = struct {
    state: []const u8, // State representation
    action: []const u8, // Action taken
    reward: f64, // Reward received
    next_state: []const u8, // Resulting state
    timestamp: i64,
    link_number: u32,

    /// Calculate discounted return
    pub fn discountedReturn(self: *const SonaEpisode, gamma: f64) f64 {
        _ = gamma;
        // DEFERRED (v12): Implement full trajectory return calculation
        // Formula: Σ (gamma^t * reward_t) for all t in trajectory
        return self.reward;
    }
};

/// Progress tracking for 999 links
pub const ProgressTracker = struct {
    current_link: u32,
    total_links: u32 = 999,
    passed_links: u32,
    failed_links: u32,
    skipped_links: u32,
    average_pas_score: f64,
    start_time: i64,

    /// Calculate completion percentage
    pub fn completionPercentage(self: *const ProgressTracker) f32 {
        return @as(f32, @floatFromInt(self.current_link)) /
            @as(f32, @floatFromInt(self.total_links)) * 100.0;
    }

    /// Calculate success rate
    pub fn successRate(self: *const ProgressTracker) f32 {
        const total = self.passed_links + self.failed_links;
        if (total == 0) return 0.0;
        return @as(f32, @floatFromInt(self.passed_links)) /
            @as(f32, @floatFromInt(total));
    }

    /// Estimate remaining links
    pub fn remainingLinks(self: *const ProgressTracker) u32 {
        return self.total_links - self.current_link;
    }
};

// Tests
test "Sacred constants" {
    try std.testing.expect(Sacred.trinityIdentity());
    const phi_val: f64 = Sacred.PHI;
    const mu_val: f64 = Sacred.MU;
    try std.testing.expectApproxEqAbs(phi_val, 1.618, 0.001);
    try std.testing.expectApproxEqAbs(mu_val, 0.0382, 0.0001);
}

test "Trinity Identity" {
    const phi_val: f64 = Sacred.PHI;
    const phi_squared = phi_val * phi_val;
    const inverse_phi_squared = 1.0 / phi_squared;
    const result = phi_squared + inverse_phi_squared;
    try std.testing.expectApproxEqAbs(result, 3.0, 0.0001);
}

test "PhiGate init and validation" {
    var gate = PhiGate.init();
    try std.testing.expect(!gate.passes()); // Should fail with zero scores

    gate.pas_score = 0.96;
    gate.confidence = 0.97;
    gate.sona_q_value = 0.8;
    try std.testing.expect(gate.passes());
}

test "LinkResult quality score" {
    var result = LinkResult{
        .link_number = 1,
        .pas_score = 0.96,
        .trinity_identity = true,
        .confidence = 0.97,
        .sona_q_value = 0.8,
        .next_action = .proceed,
        .generation_time_ms = 100,
        .validation_time_ms = 50,
    };

    try std.testing.expect(result.passedPhiGate());
    const score = result.qualityScore();
    try std.testing.expect(score > 0.8);
}

test "ProgressTracker completion" {
    var tracker = ProgressTracker{
        .current_link = 500,
        .passed_links = 450,
        .failed_links = 40,
        .skipped_links = 10,
        .average_pas_score = 0.92,
        .start_time = std.time.timestamp(),
    };

    try std.testing.expectApproxEqAbs(tracker.completionPercentage(), 50.0, 0.1);
    try std.testing.expectEqual(tracker.remainingLinks(), 499);
}

test "TaskDecomposition priority" {
    const task = TaskDecomposition{
        .name = "test",
        .description = "test task",
        .complexity = .complex,
        .estimated_lines = 750,
        .dependencies = &.{},
    };

    const priority = task.priority();
    try std.testing.expect(priority > 1.0); // φ * 0.8 ≈ 1.29
}
