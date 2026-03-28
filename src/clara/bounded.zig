// 🤖 TRINITY v0.11.0: CLARA Bounded Rationality Module
// 📋 DARPA CLARA Proposal — Restraint & HiLog
// ═══════════════════════════════════════════════════════════════════════════
//
// Implements bounded rationality through:
// - Restraint: depth limits, confidence pruning
// - HiLog: meta-rules for complexity control
// - Queen Lotus integration: quality levels → depth mapping
//
// CLARA Requirements (Grosof):
// - "Restraint & HiLog for bounded rationality"
// - Tractable inference with guaranteed termination
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const vsa = @import("vsa");
const rules_mod = @import("rules.zig");
pub const Fact = rules_mod.Fact;
pub const ProofTrace = rules_mod.ProofTrace;

/// Restraint parameters for bounded rationality
pub const Restraint = struct {
    max_depth: usize = 10,
    max_rules: usize = 100,
    confidence_threshold: f32 = 0.7,
    timeout_ms: u64 = 5000, // 5 second default

    /// Create default restraint (CLARA spec)
    pub fn default() Restraint {
        return Restraint{
            .max_depth = 10,
            .max_rules = 100,
            .confidence_threshold = 0.7,
            .timeout_ms = 5000,
        };
    }

    /// Create conservative restraint (uncertain scenarios)
    pub fn conservative() Restraint {
        return Restraint{
            .max_depth = 5,
            .max_rules = 50,
            .confidence_threshold = 0.85,
            .timeout_ms = 2000,
        };
    }

    /// Create aggressive restraint (high-confidence scenarios)
    pub fn aggressive() Restraint {
        return Restraint{
            .max_depth = 15,
            .max_rules = 200,
            .confidence_threshold = 0.5,
            .timeout_ms = 10000,
        };
    }

    /// Check if restraint allows continuing derivation
    pub fn canContinue(self: Restraint, current_depth: usize, rules_executed: usize, current_confidence: f32) bool {
        if (current_depth >= self.max_depth) return false;
        if (rules_executed >= self.max_rules) return false;
        if (current_confidence < self.confidence_threshold) return false;
        return true;
    }
};

/// Queen Lotus quality level (from storm/amygdala.zig)
pub const QualityLevel = enum {
    unknown, // Low confidence → conservative restraint
    unstable, // Medium confidence → moderate restraint
    good, // High confidence → full restraint

    /// Map quality level to restraint depth
    pub fn toRestraint(self: QualityLevel) Restraint {
        return switch (self) {
            .unknown => Restraint{
                .max_depth = 5,
                .max_rules = 50,
                .confidence_threshold = 0.85,
                .timeout_ms = 2000,
            },
            .unstable => Restraint{
                .max_depth = 8,
                .max_rules = 75,
                .confidence_threshold = 0.75,
                .timeout_ms = 3500,
            },
            .good => Restraint{
                .max_depth = 10, // CLARA max
                .max_rules = 100,
                .confidence_threshold = 0.7,
                .timeout_ms = 5000,
            },
        };
    }

    pub fn format(self: QualityLevel) []const u8 {
        return switch (self) {
            .unknown => "UNKNOWN",
            .unstable => "UNSTABLE",
            .good => "GOOD",
        };
    }
};

/// HiLog meta-rule for complexity control
pub const MetaRule = struct {
    name: []const u8,
    apply_fn: *const fn (*ExecutionState) bool,

    /// Apply meta-rule to execution state
    pub fn apply(self: MetaRule, state: *ExecutionState) bool {
        return self.apply_fn(state);
    }
};

/// Execution state for bounded derivation
pub const ExecutionState = struct {
    depth: usize = 0,
    rules_executed: usize = 0,
    current_confidence: f32 = 1.0,
    start_time: i128 = 0,
    restraint: Restraint = Restraint.default(),
    terminated: bool = false,

    /// Create new execution state
    pub fn init(restraint: Restraint) ExecutionState {
        return ExecutionState{
            .start_time = std.time.nanoTimestamp(),
            .restraint = restraint,
        };
    }

    /// Check if execution should continue
    pub fn canContinue(self: *ExecutionState) bool {
        if (self.terminated) return false;

        // Check depth limit
        if (self.depth >= self.restraint.max_depth) {
            self.terminated = true;
            return false;
        }

        // Check rules limit
        if (self.rules_executed >= self.restraint.max_rules) {
            self.terminated = true;
            return false;
        }

        // Check confidence threshold
        if (self.current_confidence < self.restraint.confidence_threshold) {
            self.terminated = true;
            return false;
        }

        // Check timeout
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        const elapsed_ms: u64 = @intCast(@divTrunc(elapsed_ns, 1_000_000));
        if (elapsed_ms >= self.restraint.timeout_ms) {
            self.terminated = true;
            return false;
        }

        return true;
    }

    /// Step execution (increment depth/rules)
    pub fn step(self: *ExecutionState, confidence_delta: f32) void {
        self.depth += 1;
        self.rules_executed += 1;
        self.current_confidence *= confidence_delta;
    }

    /// Get elapsed time in milliseconds
    pub fn elapsedMs(self: ExecutionState) u64 {
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        return @intCast(@divTrunc(elapsed_ns, 1_000_000));
    }

    /// Get termination reason
    pub fn terminationReason(self: ExecutionState) []const u8 {
        if (!self.terminated) return "Still running";
        if (self.depth >= self.restraint.max_depth) return "Max depth exceeded";
        if (self.rules_executed >= self.restraint.max_rules) return "Max rules exceeded";
        if (self.current_confidence < self.restraint.confidence_threshold) return "Confidence threshold";
        if (self.elapsedMs() >= self.restraint.timeout_ms) return "Timeout";
        return "Unknown";
    }
};

/// Apply restraint to Datalog derivation
pub fn applyRestraint(
    allocator: std.mem.Allocator,
    facts: []const Fact,
    rules_array: []const rules_mod.Rule,
    restraint: Restraint,
) !ProofTrace {
    var trace = ProofTrace.init(allocator, restraint.max_depth);
    _ = facts; // TODO: use facts in derivation
    _ = rules_array; // TODO: use rules in derivation

    // Simulate bounded derivation
    var state = ExecutionState.init(restraint);

    while (state.canContinue()) {
        // Simulate a derivation step
        const dummy_fact = Fact{ .id = 1, .value = state.current_confidence };
        try trace.addStep(dummy_fact, "bounded_rule", state.current_confidence);
        state.step(0.99); // Each step reduces confidence by 1% (gentler decay)
    }

    return trace;
}

/// Apply Queen Lotus quality-based restraint
pub fn applyQueenRestraint(
    allocator: std.mem.Allocator,
    facts: []const Fact,
    rules_array: []const rules_mod.Rule,
    quality: QualityLevel,
) !ProofTrace {
    const restraint = quality.toRestraint();
    return applyRestraint(allocator, facts, rules_array, restraint);
}

// ═══════════════════════════════════════════════════════════════════════════
// META-RULES (HiLog)
// ═══════════════════════════════════════════════════════════════════════════

/// Meta-rule: Stop if confidence drops below threshold
fn confidencePrune(state: *ExecutionState) bool {
    return state.current_confidence >= state.restraint.confidence_threshold;
}

/// Meta-rule: Stop if depth exceeds limit
fn depthLimit(state: *ExecutionState) bool {
    return state.depth < state.restraint.max_depth;
}

/// Meta-rule: Stop if too many rules executed
fn ruleLimit(state: *ExecutionState) bool {
    return state.rules_executed < state.restraint.max_rules;
}

/// Default meta-rules for CLARA
pub const defaultMetaRules = [_]MetaRule{
    .{ .name = "confidence_prune", .apply_fn = confidencePrune },
    .{ .name = "depth_limit", .apply_fn = depthLimit },
    .{ .name = "rule_limit", .apply_fn = ruleLimit },
};

/// Apply meta-rules to execution state
pub fn applyMetaRules(state: *ExecutionState, meta_rules: []const MetaRule) bool {
    for (meta_rules) |rule| {
        if (!rule.apply(state)) {
            return false;
        }
    }
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "CLARA: Restraint default values" {
    const restraint = Restraint.default();

    try std.testing.expectEqual(@as(usize, 10), restraint.max_depth);
    try std.testing.expectEqual(@as(usize, 100), restraint.max_rules);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), restraint.confidence_threshold, 0.01);
}

test "CLARA: Quality level to restraint mapping" {
    const unknown_restraint = QualityLevel.unknown.toRestraint();
    try std.testing.expectEqual(@as(usize, 5), unknown_restraint.max_depth);

    const unstable_restraint = QualityLevel.unstable.toRestraint();
    try std.testing.expectEqual(@as(usize, 8), unstable_restraint.max_depth);

    const good_restraint = QualityLevel.good.toRestraint();
    try std.testing.expectEqual(@as(usize, 10), good_restraint.max_depth);
}

test "CLARA: Execution state depth limit" {
    const restraint = Restraint{ .max_depth = 3, .max_rules = 100, .confidence_threshold = 0.5, .timeout_ms = 5000 };
    var state = ExecutionState.init(restraint);

    try std.testing.expect(state.canContinue());
    state.step(0.9);
    try std.testing.expect(state.canContinue());
    state.step(0.9);
    try std.testing.expect(state.canContinue());
    state.step(0.9);
    try std.testing.expect(!state.canContinue()); // depth = 3, limit reached

    try std.testing.expectEqualStrings("Max depth exceeded", state.terminationReason());
}

test "CLARA: Execution state confidence threshold" {
    const restraint = Restraint{ .max_depth = 10, .max_rules = 100, .confidence_threshold = 0.5, .timeout_ms = 5000 };
    var state = ExecutionState.init(restraint);

    state.step(0.9); // conf = 0.9
    try std.testing.expect(state.canContinue());

    state.step(0.4); // conf = 0.36 < 0.5
    try std.testing.expect(!state.canContinue());

    try std.testing.expectEqualStrings("Confidence threshold", state.terminationReason());
}

test "CLARA: Apply restraint to derivation" {
    const allocator = std.testing.allocator;

    const restraint = Restraint{ .max_depth = 3, .max_rules = 100, .confidence_threshold = 0.5, .timeout_ms = 5000 };

    var trace = try applyRestraint(allocator, &.{}, &.{}, restraint);
    defer trace.deinit();

    // Should stop after 3 steps due to depth limit
    try std.testing.expectEqual(@as(usize, 3), trace.step_count);
}

test "CLARA: Queen Lotus quality restraint" {
    const allocator = std.testing.allocator;

    // Unknown quality → conservative (5 steps max)
    var trace1 = try applyQueenRestraint(allocator, &.{}, &.{}, .unknown);
    defer trace1.deinit();
    try std.testing.expectEqual(@as(usize, 5), trace1.step_count);

    // Good quality → full (10 steps max)
    var trace2 = try applyQueenRestraint(allocator, &.{}, &.{}, .good);
    defer trace2.deinit();
    try std.testing.expectEqual(@as(usize, 10), trace2.step_count);
}

// φ² + 1/φ² = 3 | TRINITY
