// 🤖 TRINITY v0.11.0: CLARA Datalog Rules Engine
// 📋 DARPA CLARA Proposal — Layer 3: Logic Programs
// ═══════════════════════════════════════════════════════════════════════════
//
// VSA ↔ Datalog bridge for Trinity CLARA integration.
// Converts VSA vectors to Datalog facts and runs rule derivations.
//
// Architecture:
//   Layer 3: Datalog/Rules (Zodd engine)
//   Layer 2: VSA (differentiable symbolic, O(n))
//   Layer 1: HSLM (ternary neural, O(L×H²))
//
// References:
// - DARPA CLARA PA-25-07-02: "Tensor operations → Rules AR"
// - Cardiff VSA Paper: "VSA effectively models OODA cycle"
//
// φ² + 1/φ² = 3 | TRINITY

const std = @import("std");
const vsa = @import("vsa");
const zodd = @import("zodd");

/// Fact ID type (hash-based)
pub const FactId = u32;

/// Confidence score [0, 1]
pub const Confidence = f32;

/// VSA-derived Datalog fact
pub const Fact = struct {
    id: FactId,
    value: Confidence,
    vector: ?[]const i8 = null, // Optional reference to original VSA vector

    /// Create a new fact from a VSA vector
    pub fn fromVector(vec: []const i8, confidence: Confidence) !Fact {
        return Fact{
            .id = hashVector(vec),
            .value = confidence,
            .vector = vec,
        };
    }

    /// Compute simple hash for vector identity (public for kill_web usage)
    pub fn hashVector(vec: []const i8) FactId {
        var hash: FactId = 5381;
        for (vec) |v| {
            // Convert i8 to u8 (preserving bit pattern), then to u32
            const unsigned_v: u8 = @bitCast(v);
            // Use wrapping arithmetic to prevent overflow
            hash = hash *% 33 +% @as(FactId, @intCast(unsigned_v));
        }
        return hash;
    }
};

/// Datalog rule with confidence threshold
pub const Rule = struct {
    name: []const u8,
    confidence_threshold: Confidence = 0.7,
    max_depth: usize = 10,

    /// Check if fact meets confidence threshold
    pub fn accepts(self: Rule, fact: Fact) bool {
        return fact.value >= self.confidence_threshold;
    }
};

/// Single derivation step in proof trace
pub const DerivationStep = struct {
    step: usize,
    fact: Fact,
    rule: []const u8,
    confidence: Confidence,

    pub fn format(self: DerivationStep, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "Step {d}: {s} → confidence={d:.2}", .{
            self.step,
            self.rule,
            self.confidence,
        });
    }
};

/// Proof trace for explainability (CLARA requirement: ≤10 steps)
pub const ProofTrace = struct {
    steps: [10]DerivationStep,
    step_count: usize = 0,
    max_depth: usize = 10, // CLARA requirement

    pub fn init(allocator: std.mem.Allocator, max_depth: usize) ProofTrace {
        _ = allocator;
        return ProofTrace{
            .steps = undefined,
            .step_count = 0,
            .max_depth = max_depth,
        };
    }

    pub fn deinit(self: *ProofTrace) void {
        _ = self;
    }

    /// Add a derivation step
    pub fn addStep(self: *ProofTrace, fact: Fact, rule: []const u8, confidence: Confidence) !void {
        if (self.step_count >= self.max_depth) {
            return error.MaxDepthExceeded;
        }
        self.steps[self.step_count] = DerivationStep{
            .step = self.step_count + 1,
            .fact = fact,
            .rule = rule,
            .confidence = confidence,
        };
        self.step_count += 1;
    }

    /// Get final confidence (product of all step confidences)
    pub fn finalConfidence(self: ProofTrace) Confidence {
        if (self.step_count == 0) return 0.0;
        var result: Confidence = 1.0;
        for (self.steps[0..self.step_count]) |step| {
            result *= step.confidence;
        }
        return result;
    }

    /// Format proof trace for display
    pub fn format(self: ProofTrace, writer: anytype) !void {
        try writer.print("\n╔══════════════════════════════════════════════════════════╗\n", .{});
        try writer.print("║  CLARA Proof Trace ({d} steps, max depth: {d})           ║\n", .{ self.step_count, self.max_depth });
        try writer.print("╠══════════════════════════════════════════════════════════╣\n", .{});

        for (self.steps[0..self.step_count]) |step| {
            try writer.print("║ Step {d:2}: {s:40} │ conf: {d:.3} ║\n", .{
                step.step,
                step.rule,
                step.confidence,
            });
        }

        try writer.print("╠══════════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║  Final Confidence: {d:.3}                               ║\n", .{self.finalConfidence()});
        try writer.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    }
};

/// Convert VSA vector to Datalog fact
pub fn vsaToFact(vec: []const i8, confidence: Confidence) !Fact {
    return Fact.fromVector(vec, confidence);
}

/// Convert batch of VSA vectors to facts
pub fn vsaBatchToFacts(allocator: std.mem.Allocator, vectors: []const []const i8, confidence: Confidence) ![]Fact {
    const facts = try allocator.alloc(Fact, vectors.len);
    errdefer allocator.free(facts);

    for (vectors, 0..) |vec, i| {
        facts[i] = try vsaToFact(vec, confidence);
    }

    return facts;
}

/// Run Datalog rules with VSA-derived facts
pub fn runRules(allocator: std.mem.Allocator, facts: []const Fact, rules: []const Rule) !ProofTrace {
    var trace = ProofTrace.init(allocator, 10);
    errdefer trace.deinit();

    // Simple rule engine (fixed-point iteration)
    // TODO: Integrate with Zodd for full Datalog semantics
    for (rules) |rule| {
        for (facts) |fact| {
            if (rule.accepts(fact)) {
                try trace.addStep(fact, rule.name, fact.value);
            }
        }
    }

    return trace;
}

/// Default CLARA rules for threat classification
pub const defaultRules = [_]Rule{
    .{ .name = "vsa_similarity_high", .confidence_threshold = 0.85 },
    .{ .name = "vsa_similarity_medium", .confidence_threshold = 0.70 },
    .{ .name = "vsa_similarity_low", .confidence_threshold = 0.50 },
};

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "CLARA: Fact from VSA vector" {
    const allocator = std.testing.allocator;

    // Create a simple test vector
    var test_vec = try allocator.alloc(i8, 100);
    defer allocator.free(test_vec);
    for (0..100) |i| {
        // Pattern: -1, 0, 1 (ternary values)
        const rem = @as(i8, @intCast(i % 3));
        test_vec[i] = rem - 1;
    }

    const fact = try vsaToFact(test_vec, 0.85);

    try std.testing.expect(fact.value == 0.85);
    try std.testing.expect(fact.id != 0); // Hash should be non-zero
}

test "CLARA: Rule confidence threshold" {
    const rule = Rule{ .name = "test_rule", .confidence_threshold = 0.7 };

    const high_conf_fact = Fact{ .id = 1, .value = 0.85 };
    const low_conf_fact = Fact{ .id = 2, .value = 0.5 };

    try std.testing.expect(rule.accepts(high_conf_fact));
    try std.testing.expect(!rule.accepts(low_conf_fact));
}

test "CLARA: Proof trace max depth" {
    const allocator = std.testing.allocator;

    var trace = ProofTrace.init(allocator, 3);
    defer trace.deinit();

    const fact = Fact{ .id = 1, .value = 0.8 };

    // Should succeed for first 3 steps
    try trace.addStep(fact, "rule1", 0.9);
    try trace.addStep(fact, "rule2", 0.9);
    try trace.addStep(fact, "rule3", 0.9);

    // 4th step should fail
    const result = trace.addStep(fact, "rule4", 0.9);
    try std.testing.expectError(error.MaxDepthExceeded, result);
}

test "CLARA: Proof trace final confidence" {
    const allocator = std.testing.allocator;

    var trace = ProofTrace.init(allocator, 10);
    defer trace.deinit();

    const fact = Fact{ .id = 1, .value = 0.9 };

    try trace.addStep(fact, "rule1", 0.9);
    try trace.addStep(fact, "rule2", 0.8);

    // Final confidence = 0.9 * 0.8 = 0.72
    const final = trace.finalConfidence();
    try std.testing.expectApproxEqAbs(0.72, final, 0.01);
}

test "CLARA: Run rules with facts" {
    const allocator = std.testing.allocator;

    var facts = [_]Fact{
        .{ .id = 1, .value = 0.9 },
        .{ .id = 2, .value = 0.6 },
    };

    const rules = [_]Rule{
        .{ .name = "high_conf", .confidence_threshold = 0.7 },
        .{ .name = "low_conf", .confidence_threshold = 0.5 },
    };

    var trace = try runRules(allocator, &facts, &rules);
    defer trace.deinit();

    // Should have 3 derivations:
    // - high_conf accepts fact 1 (0.9 >= 0.7)
    // - low_conf accepts fact 1 (0.9 >= 0.5)
    // - low_conf accepts fact 2 (0.6 >= 0.5)
    try std.testing.expect(trace.step_count == 3);
}

// φ² + 1/φ² = 3 | TRINITY
