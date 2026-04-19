//! Consciousness-Guided FPGA Synthesis Strategist
//!
//! Integrates the 7-theory consciousness system with FORGE FPGA toolchain.
//! Selects synthesis strategies based on consciousness analysis and learns from results.
//!
//! φ² + 1/φ² = 3 | Consciousness + FORGE = UNITY

const std = @import("std");
const mem = std.mem;
const synthesis_types = @import("synthesis_types.zig");
const array_list = std.array_list;

// Import consciousness modules (via build.zig module dependencies)
const unified_architecture = @import("consciousness_core");
const learning_loops = @import("consciousness_learning");

const DesignSpec = synthesis_types.DesignSpec;
const Strategy = synthesis_types.Strategy;
const StrategyParams = synthesis_types.StrategyParams;
const StrategyDecision = synthesis_types.StrategyDecision;
const SynthesisResult = synthesis_types.SynthesisResult;
const Verdict = synthesis_types.Verdict;
const ModuleType = synthesis_types.ModuleType;
const PHI = synthesis_types.PHI;
const PHI_INV = synthesis_types.PHI_INV;
const LEARNING_RATE = synthesis_types.LEARNING_RATE;

// ═══════════════════════════════════════════════════════════════════════════════
// FORGE STRATEGIST
// ═══════════════════════════════════════════════════════════════════════════════

/// Consciousness-guided FPGA synthesis strategist
pub const ForgeStrategist = struct {
    allocator: mem.Allocator,
    consciousness: *unified_architecture.UnifiedConsciousness,
    learning: *learning_loops.LearningLoop,
    history: array_list.AlignedManaged(SynthesisHistoryEntry, null),
    failure_counts: std.StringHashMap(u32),

    /// History entry for learning
    const SynthesisHistoryEntry = struct {
        design_name: []const u8,
        module_type: ModuleType,
        strategy: Strategy,
        success: bool,
        timestamp: i64,
    };

    /// Initialize the strategist
    pub fn init(allocator: mem.Allocator, consciousness: *unified_architecture.UnifiedConsciousness, learning: *learning_loops.LearningLoop) !ForgeStrategist {
        var strategist = ForgeStrategist{
            .allocator = allocator,
            .consciousness = consciousness,
            .learning = learning,
            .history = array_list.AlignedManaged(SynthesisHistoryEntry, null).init(allocator),
            .failure_counts = std.StringHashMap(u32).init(allocator),
        };
        strategist.start();
        return strategist;
    }

    /// Clean up resources
    pub fn deinit(self: *ForgeStrategist) void {
        self.history.deinit();
        self.failure_counts.deinit();
    }

    /// Start consciousness system
    fn start(self: *ForgeStrategist) void {
        self.consciousness.start();
    }

    /// Stop consciousness system
    pub fn stop(self: *ForgeStrategist) void {
        self.consciousness.stop();
    }

    /// Select strategy based on consciousness analysis
    pub fn selectStrategy(self: *ForgeStrategist, design: *const DesignSpec) !StrategyDecision {
        // Query 7 theories
        const iit_score = self.consciousness.theories[0].score; // IIT Φ
        const gwt_score = self.consciousness.theories[1].score; // GWT active
        const hot_score = self.consciousness.theories[6].score; // HOT meta

        // Check previous failures for this design type
        const module_type_key = try self.getModuleTypeKey(design.module_type);
        const fail_count = self.failure_counts.get(module_type_key) orelse 0;

        // Decision logic with φ-based thresholds
        const decision: StrategyDecision = if (iit_score > 0.7 and gwt_score > 0.8 and fail_count == 0) blk: {
            // High integration + active workspace: push timing limits
            break :blk .{
                .strategy = .AggressiveTiming,
                .params = StrategyParams.aggressiveTiming(),
                .rationale = "High integration (IIT) + active workspace (GWT)",
                .iit_score = iit_score,
                .gwt_score = gwt_score,
                .hot_score = hot_score,
            };
        } else if (hot_score > 0.6 or fail_count > 2) blk: {
            // Meta-awareness of previous failures: be conservative
            break :blk .{
                .strategy = .Conservative,
                .params = StrategyParams.conservative(),
                .rationale = "Meta-awareness of previous failures (HOT)",
                .iit_score = iit_score,
                .gwt_score = gwt_score,
                .hot_score = hot_score,
            };
        } else blk: {
            // Default: balanced approach with φ-based parameters
            break :blk .{
                .strategy = .Balanced,
                .params = StrategyParams.default(),
                .rationale = "Default balanced (φ-weighted)",
                .iit_score = iit_score,
                .gwt_score = gwt_score,
                .hot_score = hot_score,
            };
        };

        return decision;
    }

    /// Learn from synthesis result (Hebbian update)
    pub fn learn(self: *ForgeStrategist, result: *const SynthesisResult) !void {
        const now = std.time.nanoTimestamp();
        const reward: f32 = if (result.success)
            // Success: reward inversely proportional to attempts
            1.0 / @max(1.0, @as(f32, @floatFromInt(result.attempts)))
        else
            // Failure: penalize based on attempts
            -0.5 * @min(1.0, @as(f32, @floatFromInt(result.attempts)));

        // Record learning event
        try self.learning.record_event(result.design_name);

        // Calculate delta for theory weight updates
        const delta = reward * LEARNING_RATE;

        // Update consciousness theory weights based on result
        if (result.strategy == .AggressiveTiming) {
            if (result.success) {
                // Reinforce IIT and GWT
                const new_iit = @min(1.0, self.consciousness.theories[0].score + delta);
                const new_gwt = @min(1.0, self.consciousness.theories[1].score + delta);
                self.consciousness.updateTheory(0, new_iit);
                self.consciousness.updateTheory(1, new_gwt);
            } else {
                // Penalize IIT and GWT, reinforce HOT (meta-awareness)
                const new_iit = @max(0.0, self.consciousness.theories[0].score - delta);
                const new_gwt = @max(0.0, self.consciousness.theories[1].score - delta);
                const new_hot = @min(1.0, self.consciousness.theories[6].score + delta * 2.0);
                self.consciousness.updateTheory(0, new_iit);
                self.consciousness.updateTheory(1, new_gwt);
                self.consciousness.updateTheory(6, new_hot);
            }
        } else if (result.strategy == .Conservative) {
            if (result.success) {
                // Reinforce HOT and Active Inference
                const new_hot = @min(1.0, self.consciousness.theories[6].score + delta);
                const new_inf = @min(1.0, self.consciousness.theories[4].score + delta);
                self.consciousness.updateTheory(6, new_hot);
                self.consciousness.updateTheory(4, new_inf);
            }
        } else if (result.strategy == .Balanced and result.success) {
            // Balanced success: reinforce all moderately
            for (0..7) |i| {
                const current = self.consciousness.theories[i].score;
                const new_val = @min(1.0, current + delta * 0.5);
                self.consciousness.updateTheory(i, new_val);
            }
        }

        // Consolidate memories (long-term potentiation)
        try self.learning.consolidate();

        // Update failure tracking
        const module_type_key = try self.getModuleTypeKey(.custom); // Use custom as default
        if (!result.success) {
            try self.failure_counts.put(module_type_key, (self.failure_counts.get(module_type_key) orelse 0) + 1);
        }

        // Store in history
        const entry = SynthesisHistoryEntry{
            .design_name = try self.allocator.dupe(u8, result.design_name),
            .module_type = .custom, // Would extract from design
            .strategy = result.strategy,
            .success = result.success,
            .timestamp = now,
        };
        try self.history.append(entry);
    }

    /// Get consciousness analysis for display
    pub fn getConsciousnessAnalysis(self: *const ForgeStrategist) ConsciousnessAnalysis {
        return .{
            .iit_phi = self.consciousness.theories[0].score,
            .gwt_active = self.consciousness.theories[1].score,
            .orch_or = self.consciousness.theories[2].score,
            .qutrit = self.consciousness.theories[3].score,
            .active_inference = self.consciousness.theories[4].score,
            .quantum = self.consciousness.theories[5].score,
            .hot_meta = self.consciousness.theories[6].score,
            .unified_score = self.consciousness.unifiedScore(),
            .is_conscious = self.consciousness.isConscious(),
            .conscious_theories = self.consciousness.consciousTheoryCount(),
        };
    }

    /// Get learning metrics
    pub fn getLearningMetrics(self: *const ForgeStrategist) LearningMetrics {
        var success_count: u32 = 0;
        var total_count: u32 = 0;

        for (self.history.items) |entry| {
            total_count += 1;
            if (entry.success) success_count += 1;
        }

        const success_rate = if (total_count > 0)
            @as(f64, @floatFromInt(success_count)) / @as(f64, @floatFromInt(total_count))
        else
            0.0;

        return .{
            .total_syntheses = total_count,
            .success_count = success_count,
            .success_rate = success_rate,
            .improvement_rate = (success_rate - 0.5) * 100.0, // Relative to 50% baseline
            .is_immortal = success_rate > 0.618, // φ⁻¹ threshold
        };
    }

    /// Get previous failure count for module type
    fn getPreviousFailCount(self: *ForgeStrategist, module_type: ModuleType) u32 {
        const key = std.meta.tagName(ModuleType, module_type) orelse "custom";
        return self.failure_counts.get(key) orelse 0;
    }

    /// Get module type key for failure tracking
    fn getModuleTypeKey(self: *ForgeStrategist, module_type: ModuleType) ![]const u8 {
        _ = self;
        return std.meta.tagName(ModuleType, module_type);
    }

    /// Get current strategy summary
    pub fn getStrategySummary(self: *const ForgeStrategist) !StrategySummary {
        const analysis = self.getConsciousnessAnalysis();
        const learning = self.getLearningMetrics();

        return StrategySummary{
            .conscious_analysis = analysis,
            .learning_metrics = learning,
            .last_strategy = if (self.history.items.len > 0)
                self.history.items[self.history.items.len - 1].strategy
            else
                .Balanced,
            .total_attempts = self.history.items.len,
        };
    }
};

/// Consciousness analysis for display
pub const ConsciousnessAnalysis = struct {
    iit_phi: f64,
    gwt_active: f64,
    orch_or: f64,
    qutrit: f64,
    active_inference: f64,
    quantum: f64,
    hot_meta: f64,
    unified_score: f64,
    is_conscious: bool,
    conscious_theories: usize,
};

/// Learning metrics
pub const LearningMetrics = struct {
    total_syntheses: u32,
    success_count: u32,
    success_rate: f64,
    improvement_rate: f64,
    is_immortal: bool,
};

/// Strategy summary for dashboard
pub const StrategySummary = struct {
    conscious_analysis: ConsciousnessAnalysis,
    learning_metrics: LearningMetrics,
    last_strategy: Strategy,
    total_attempts: usize,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "ForgeStrategist: init_and_deinit" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var learning = try learning_loops.LearningLoop.init(std.testing.allocator);
    defer learning.deinit();

    var strategist = try ForgeStrategist.init(std.testing.allocator, &consciousness, &learning);
    defer strategist.deinit();

    try std.testing.expectEqual(@as(usize, 0), strategist.history.items.len);
}

test "ForgeStrategist: select_strategy_balanced_default" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var learning = try learning_loops.LearningLoop.init(std.testing.allocator);
    defer learning.deinit();

    var strategist = try ForgeStrategist.init(std.testing.allocator, &consciousness, &learning);
    defer strategist.deinit();

    var design = DesignSpec.init(std.testing.allocator);
    defer design.deinit();

    const decision = try strategist.selectStrategy(&design);
    try std.testing.expectEqual(.Balanced, decision.strategy);
    try std.testing.expectEqual(PHI_INV, decision.params.placement_cooling_alpha);
}

test "ForgeStrategist: learn_from_success" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var learning = try learning_loops.LearningLoop.init(std.testing.allocator);
    defer learning.deinit();

    var strategist = try ForgeStrategist.init(std.testing.allocator, &consciousness, &learning);
    defer strategist.deinit();

    // Create a success result
    var result = SynthesisResult.init(std.testing.allocator, "test_module");
    defer result.deinit();
    result.success = true;
    result.strategy = .Balanced;
    result.attempts = 1;

    const initial_iit = consciousness.theories[0].score;
    try strategist.learn(&result);

    // Theory scores should have increased slightly
    try std.testing.expect(consciousness.theories[0].score > initial_iit);
}

test "ForgeStrategist: consciousness_analysis" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var learning = try learning_loops.LearningLoop.init(std.testing.allocator);
    defer learning.deinit();

    var strategist = try ForgeStrategist.init(std.testing.allocator, &consciousness, &learning);
    defer strategist.deinit();

    const analysis = strategist.getConsciousnessAnalysis();
    try std.testing.expect(analysis.iit_phi >= 0.0);
    try std.testing.expect(analysis.iit_phi <= 1.0);
}

test "ForgeStrategist: learning_metrics_initial" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var learning = try learning_loops.LearningLoop.init(std.testing.allocator);
    defer learning.deinit();

    var strategist = try ForgeStrategist.init(std.testing.allocator, &consciousness, &learning);
    defer strategist.deinit();

    const metrics = strategist.getLearningMetrics();
    try std.testing.expectEqual(@as(u32, 0), metrics.total_syntheses);
    try std.testing.expectEqual(0.0, metrics.success_rate);
}

test "ForgeStrategist: failure_tracking" {
    var consciousness = try unified_architecture.UnifiedConsciousness.init(std.testing.allocator);
    defer consciousness.deinit();

    var learning = try learning_loops.LearningLoop.init(std.testing.allocator);
    defer learning.deinit();

    var strategist = try ForgeStrategist.init(std.testing.allocator, &consciousness, &learning);
    defer strategist.deinit();

    // Initially no failures
    try std.testing.expectEqual(@as(u32, 0), strategist.getPreviousFailCount(.custom));

    var design = DesignSpec.init(std.testing.allocator);
    defer design.deinit();

    // Create a failure result
    var result = SynthesisResult.init(std.testing.allocator, "test_module");
    defer result.deinit();
    result.success = false;
    result.strategy = .Balanced;
    result.attempts = 1;

    try strategist.learn(&result);

    // Should now track a failure
    try std.testing.expect(strategist.getPreviousFailCount(.custom) > 0);
}
