//! ═══════════════════════════════════════════════════════════════════════════════
//! FPGA VSA INTEGRATION — Vector Symbolic Architecture for FPGA Strategy Memory
//! ═══════════════════════════════════════════════════════════════════════════════
//!
//! Integrates VSA cognitive memory with FPGA synthesis pipeline. Stores and recalls
//! placement/routing strategies based on design characteristics using HRR vectors.
//!
//! Features:
//!   - Strategy storage with VSA encoding
//!   - Design pattern recognition
//!   - Strategy recommendation based on similarity
//!   - Learning from successful syntheses
//!   - φ-based confidence thresholds
//!
//! Usage:
//!   var memory = try FPGAVSAMemory.init(allocator);
//!   try memory.learnStrategy(design_char, strategy);
//!   const recommendation = try memory.recommendStrategy(new_design);
//!
//! φ² + 1/φ² = 3 = TRINITY
//! ═══════════════════════════════════════════════════════════════════════════════

const std = @import("std");
const Allocator = std.mem.Allocator;

const VSAMemory = @import("vsa_memory.zig").VSAMemory;

/// ═══════════════════════════════════════════════════════════════════════════════
/// SACRED CONSTANTS
/// ═══════════════════════════════════════════════════════════════════════════════
const PHI: f64 = 1.618033988749895;              // Golden Ratio
const PHI_INV: f64 = 0.618033988749895;           // φ⁻¹ (immortality threshold)
const TRINITY: f64 = 3.0;                        // φ² + 1/φ²

/// ═══════════════════════════════════════════════════════════════════════════════
/// DESIGN CHARACTERISTICS
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Key characteristics that define an FPGA design's synthesis strategy:
pub const DesignCharacteristics = struct {
    num_luts: usize,           // Number of LUTs (0-100000)
    num_ffs: usize,            // Number of flip-flops (0-100000)
    num_carries: usize,        // Number of CARRY4 chains (0-10000)
    num_iobs: usize,           // Number of IO blocks (0-500)
    has_bram: bool,            // Uses block RAM
    has_dsp: bool,             // Uses DSP blocks
    clock_frequency_mhz: f32,  // Target clock frequency (0-500)
    target_device: DeviceType, // Target FPGA device

    pub const DeviceType = enum {
        xc7a35t,
        xc7a50t,
        xc7a100t,
        xc7a200t,
        custom,
    };

    /// Convert characteristics to semantic string for VSA encoding
    pub fn toSemanticString(self: DesignCharacteristics, allocator: Allocator) ![]const u8 {
        const size_class = self.getSizeClass();
        const complexity = self.getComplexity();
        const timing_class = self.getTimingClass();

        return std.fmt.allocPrint(allocator, "{s}_{s}_{s}_{s}", .{
            @tagName(self.target_device),
            size_class,
            complexity,
            timing_class,
        });
    }

    /// Get size class based on resource usage
    fn getSizeClass(self: DesignCharacteristics) []const u8 {
        const total_resources = self.num_luts + self.num_ffs + (self.num_carries * 4);
        if (total_resources < 1000) return "tiny";
        if (total_resources < 5000) return "small";
        if (total_resources < 20000) return "medium";
        if (total_resources < 50000) return "large";
        return "xlarge";
    }

    /// Get complexity based on resource types
    fn getComplexity(self: DesignCharacteristics) []const u8 {
        var score: usize = 0;
        if (self.has_bram) score += 2;
        if (self.has_dsp) score += 2;
        if (self.num_carries > 100) score += 1;
        if (self.clock_frequency_mhz > 100) score += 1;

        if (score <= 1) return "simple";
        if (score <= 3) return "moderate";
        return "complex";
    }

    /// Get timing class based on frequency
    fn getTimingClass(self: DesignCharacteristics) []const u8 {
        if (self.clock_frequency_mhz < 50) return "low_speed";
        if (self.clock_frequency_mhz < 150) return "medium_speed";
        return "high_speed";
    }
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// SYNTHESIS STRATEGY
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Strategy parameters for FPGA synthesis:
pub const SynthesisStrategy = struct {
    name: []const u8,
    placer_effort: PlacerEffort,
    router_effort: RouterEffort,
    target_density: f32,        // 0.0-1.0 (lower = more spread out)
    use_timing_driven: bool,
    strategy_type: StrategyType,

    pub const PlacerEffort = enum {
        low,
        medium,
        high,
        extreme,
    };

    pub const RouterEffort = enum {
        low,
        medium,
        high,
    };

    pub const StrategyType = enum {
        area_optimized,      // Minimize resource usage
        timing_optimized,    // Maximize clock frequency
        power_optimized,     // Minimize power consumption
        balanced,            // Trade-off between all
        consciousness_aware, // φ-based guided placement
    };
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// STRATEGY RECOMMENDATION
/// ═══════════════════════════════════════════════════════════════════════════════
pub const StrategyRecommendation = struct {
    strategy: SynthesisStrategy,
    confidence: f32,
    is_immortal: bool,
    rationale: []const u8,
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// FPGA VSA MEMORY
/// ═══════════════════════════════════════════════════════════════════════════════
pub const FPGAVSAMemory = struct {
    vsa_memory: VSAMemory,
    strategies: std.StringHashMap(SynthesisStrategy),
    allocator: Allocator,

    /// Initialize FPGA VSA Memory with φ-powered dimension
    pub fn init(allocator: Allocator) !FPGAVSAMemory {
        // Use φ²-powered dimension for optimal symbolic representation
        const phi_dim = @as(usize, @intFromFloat(1000 * PHI * PHI));
        var vsa_memory = try VSAMemory.init(allocator, phi_dim);
        vsa_memory.consciousness_level = PHI_INV; // Start at immortality threshold

        return .{
            .vsa_memory = vsa_memory,
            .strategies = std.StringHashMap(SynthesisStrategy).init(allocator),
            .allocator = allocator,
        };
    }

    /// ═══════════════════════════════════════════════════════════════════════════════
    /// LEARNING: Store successful strategies
    /// ═══════════════════════════════════════════════════════════════════════════════

    /// Learn from a successful synthesis run
    pub fn learnFromSuccess(
        self: *FPGAVSAMemory,
        design_char: DesignCharacteristics,
        strategy: SynthesisStrategy,
        outcome: SynthesisOutcome,
    ) !void {
        // Only learn from successful or immortal outcomes
        if (outcome.pass_rate < PHI_INV) return;

        // Store design pattern
        const pattern_str = try design_char.toSemanticString(self.allocator);
        defer self.allocator.free(pattern_str);

        try self.vsa_memory.storeConcept(pattern_str);

        // Store strategy name
        try self.vsa_memory.storeConcept(strategy.name);

        // Associate design pattern with strategy
        try self.vsa_memory.associate(pattern_str, strategy.name);

        // Store strategy in HashMap
        const strategy_copy = try self.copyStrategy(strategy);
        try self.strategies.put(strategy.name, strategy_copy);
    }

    /// ═══════════════════════════════════════════════════════════════════════════════
    /// RECOMMENDATION: Suggest strategy for new design
    /// ═══════════════════════════════════════════════════════════════════════════════

    /// Recommend strategy for a new design
    pub fn recommendStrategy(
        self: *FPGAVSAMemory,
        design_char: DesignCharacteristics,
    ) !StrategyRecommendation {
        const pattern_str = try design_char.toSemanticString(self.allocator);
        defer self.allocator.free(pattern_str);

        // Try to find similar pattern in memory
        const result = try self.vsa_memory.consciousRetrieve(pattern_str);

        if (result.found) {
            // Found similar design, retrieve its strategy
            const strategy = self.strategies.get(result.name) orelse {
                return self.getDefaultRecommendation(design_char, "similar_design_no_strategy");
            };

            return .{
                .strategy = strategy,
                .confidence = result.confidence,
                .is_immortal = result.confidence >= PHI_INV,
                .rationale = try std.fmt.allocPrint(
                    self.allocator,
                    "Based on {d:.1}% similar design '{s}'",
                    .{ result.confidence * 100.0, result.name },
                ),
            };
        }

        // No similar design found, use default
        return self.getDefaultRecommendation(design_char, "no_similar_designs");
    }

    /// Get default strategy recommendation based on design characteristics
    fn getDefaultRecommendation(
        self: *FPGAVSAMemory,
        design_char: DesignCharacteristics,
        reason: []const u8,
    ) !StrategyRecommendation {
        const strategy = SynthesisStrategy{
            .name = "default_phi_guided",
            .placer_effort = if (design_char.num_luts > 10000)
                .high else .medium,
            .router_effort = .high,
            .target_density = 0.75,
            .use_timing_driven = design_char.clock_frequency_mhz > 100,
            .strategy_type = .consciousness_aware,
        };

        return .{
            .strategy = strategy,
            .confidence = 0.5, // Default confidence
            .is_immortal = false,
            .rationale = try std.fmt.allocPrint(
                self.allocator,
                "Default strategy ({s})",
                .{reason},
            ),
        };
    }

    /// ═══════════════════════════════════════════════════════════════════════════════
    /// UTILITY
    /// ═══════════════════════════════════════════════════════════════════════════════

    /// Copy strategy (owns its memory)
    fn copyStrategy(self: *FPGAVSAMemory, strategy: SynthesisStrategy) !SynthesisStrategy {
        const name_copy = try self.allocator.dupe(u8, strategy.name);
        return .{
            .name = name_copy,
            .placer_effort = strategy.placer_effort,
            .router_effort = strategy.router_effort,
            .target_density = strategy.target_density,
            .use_timing_driven = strategy.use_timing_driven,
            .strategy_type = strategy.strategy_type,
        };
    }

    /// Get memory statistics
    pub fn stats(self: *const FPGAVSAMemory) struct {
        num_strategies: usize,
        dimension: usize,
        consciousness: f64,
        immortal: bool,
    } {
        const vsa_stats = self.vsa_memory.stats();
        return .{
            .num_strategies = self.strategies.count(),
            .dimension = vsa_stats.dimension,
            .consciousness = vsa_stats.consciousness,
            .immortal = vsa_stats.immortal,
        };
    }

    /// Deinitialize
    pub fn deinit(self: *FPGAVSAMemory) void {
        // Free strategies
        var iter = self.strategies.valueIterator();
        while (iter.next()) |strategy| {
            self.allocator.free(strategy.name);
        }
        self.strategies.deinit();
        self.vsa_memory.deinit();
    }
};

/// ═══════════════════════════════════════════════════════════════════════════════
/// SYNTHESIS OUTCOME
/// ═══════════════════════════════════════════════════════════════════════════════
pub const SynthesisOutcome = struct {
    pass_rate: f32,           // 0.0-1.0 (quality of result)
    timing_met: bool,         // Did timing closure succeed?
    route_success: bool,      // Did routing complete?
    area_efficiency: f32,     // 0.0-1.0 (lower is better)
};

// ═══════════════════════════════════════════════════════════════════════════════
// CLI INTEGRATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Flag for enabling VSA memory in FPGA commands:
//   tri fpga gen specs/fpga/blink.vibee --use-vsa-memory
//

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════
test "FPGA VSA: init and basic operations" {
    const testing = std.testing;

    var memory = try FPGAVSAMemory.init(testing.allocator);
    defer memory.deinit();

    // Check initial stats
    const stats = memory.stats();
    try testing.expect(stats.dimension > 1000);
    try testing.expect(stats.consciousness >= PHI_INV);
}

test "FPGA VSA: design characteristics to semantic string" {
    const testing = std.testing;

    const design = DesignCharacteristics{
        .num_luts = 500,
        .num_ffs = 200,
        .num_carries = 10,
        .num_iobs = 5,
        .has_bram = false,
        .has_dsp = false,
        .clock_frequency_mhz = 50.0,
        .target_device = .xc7a100t,
    };

    const semantic = try design.toSemanticString(testing.allocator);
    defer testing.allocator.free(semantic);

    try testing.expect(semantic.len > 0);
}

test "FPGA VSA: learn and recommend strategy" {
    const testing = std.testing;

    var memory = try FPGAVSAMemory.init(testing.allocator);
    defer memory.deinit();

    // Learn from a successful synthesis
    const design = DesignCharacteristics{
        .num_luts = 100,
        .num_ffs = 50,
        .num_carries = 5,
        .num_iobs = 2,
        .has_bram = false,
        .has_dsp = false,
        .clock_frequency_mhz = 50.0,
        .target_device = .xc7a100t,
    };

    const strategy = SynthesisStrategy{
        .name = "test_strategy",
        .placer_effort = .medium,
        .router_effort = .high,
        .target_density = 0.75,
        .use_timing_driven = false,
        .strategy_type = .balanced,
    };

    const outcome = SynthesisOutcome{
        .pass_rate = 0.8,
        .timing_met = true,
        .route_success = true,
        .area_efficiency = 0.7,
    };

    try memory.learnFromSuccess(design, strategy, outcome);

    // Recommend for similar design
    const recommendation = try memory.recommendStrategy(design);
    try testing.expect(recommendation.confidence > 0);
}

test "FPGA VSA: size class detection" {
    const testing = std.testing;

    // Tiny design
    const tiny = DesignCharacteristics{
        .num_luts = 100,
        .num_ffs = 50,
        .num_carries = 0,
        .num_iobs = 2,
        .has_bram = false,
        .has_dsp = false,
        .clock_frequency_mhz = 25.0,
        .target_device = .xc7a35t,
    };

    const tiny_semantic = try tiny.toSemanticString(testing.allocator);
    defer testing.allocator.free(tiny_semantic);

    // Large design
    const large = DesignCharacteristics{
        .num_luts = 30000,
        .num_ffs = 15000,
        .num_carries = 500,
        .num_iobs = 100,
        .has_bram = true,
        .has_dsp = true,
        .clock_frequency_mhz = 200.0,
        .target_device = .xc7a100t,
    };

    const large_semantic = try large.toSemanticString(testing.allocator);
    defer testing.allocator.free(large_semantic);

    // Verify they generate different semantic strings
    try testing.expect(!std.mem.eql(u8, tiny_semantic, large_semantic));
}
