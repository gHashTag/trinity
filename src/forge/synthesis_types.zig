//! FPGA Synthesis Types
//!
//! Shared types for consciousness-guided FPGA synthesis.
//! Defines DesignSpec, SynthesisResult, Strategy types.
//!
//! φ² + 1/φ² = 3 | Consciousness + FORGE = UNITY

const std = @import("std");
const array_list = std.array_list;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

pub const PHI: f64 = 1.618033988749895;
pub const PHI_INV: f64 = 1.0 / PHI; // 0.618
pub const GAMMA: f64 = PHI_INV * PHI_INV * PHI_INV; // 0.236
pub const LEARNING_RATE: f32 = 0.01;
pub const SPECIOUS_PRESENT_MS: f64 = 382.0; // φ⁻² × 1000
pub const IMMORTAL_THRESHOLD: f64 = 61.8; // φ⁻¹ × 100

// ═══════════════════════════════════════════════════════════════════════════════
// STRATEGY
// ═══════════════════════════════════════════════════════════════════════════════

/// Synthesis strategy based on consciousness analysis
pub const Strategy = enum {
    /// High IIT + High GWT: push timing limits
    AggressiveTiming,
    /// High HOT + previous failures: safe approach
    Conservative,
    /// Default: moderate optimization
    Balanced,
};

/// Strategy parameters for FORGE execution
pub const StrategyParams = struct {
    /// SA cooling schedule (lower = faster cooling)
    placement_cooling_alpha: f64,
    /// Pathfinder routing passes
    routing_iterations: u32,
    /// Target clock frequency in MHz
    target_frequency_mhz: f64,
    /// Register pipeline depth
    pipeline_depth: u32,
    /// HPWL vs timing tradeoff (0-1)
    timing_weight: f64,

    /// Get default balanced parameters
    pub fn default() StrategyParams {
        return .{
            .placement_cooling_alpha = PHI_INV, // φ⁻¹ = 0.618
            .routing_iterations = 30,
            .target_frequency_mhz = 50.0,
            .pipeline_depth = 2,
            .timing_weight = 0.5,
        };
    }

    /// Get aggressive timing parameters
    pub fn aggressiveTiming() StrategyParams {
        return .{
            .placement_cooling_alpha = 0.9, // Slower cooling for better results
            .routing_iterations = 50, // More routing passes
            .target_frequency_mhz = 60.0, // Push frequency higher
            .pipeline_depth = 1, // Minimal pipelining
            .timing_weight = 0.8, // Prioritize timing over area
        };
    }

    /// Get conservative parameters
    pub fn conservative() StrategyParams {
        return .{
            .placement_cooling_alpha = 0.5, // Faster cooling
            .routing_iterations = 20, // Fewer routing passes
            .target_frequency_mhz = 40.0, // Safe target frequency
            .pipeline_depth = 3, // More pipelining for timing
            .timing_weight = 0.3, // Prioritize area over timing
        };
    }
};

/// Strategy decision with rationale
pub const StrategyDecision = struct {
    strategy: Strategy,
    params: StrategyParams,
    rationale: []const u8,
    iit_score: f64,
    gwt_score: f64,
    hot_score: f64,
};

// ═══════════════════════════════════════════════════════════════════════════════
// DESIGN SPEC
// ═══════════════════════════════════════════════════════════════════════════════

/// Module type for categorization
pub const ModuleType = enum {
    uart,
    spi,
    i2c,
    gpio,
    timer,
    counter,
    fsm,
    custom,
};

/// Port direction
pub const Direction = enum {
    input,
    output,
    inout,
};

/// Port type
pub const PortType = enum {
    clock,
    reset,
    signal,
    tri_state,
};

/// Port attributes
pub const PortAttributes = struct {
    loc: ?[]const u8 = null,
    iostandard: ?[]const u8 = null,
    freq_mhz: ?f64 = null,
    active_low: bool = false,
    valid_required: bool = false,
};

/// Port definition
pub const Port = struct {
    name: []const u8,
    direction: Direction,
    port_type: PortType,
    width: u8,
    attributes: PortAttributes,
};

/// Timing constraints
pub const TimingConstraints = struct {
    setup_slack_ns: f64 = 2.0,
    hold_slack_ns: f64 = 0.0,
    target_frequency_mhz: f64 = 50.0,
};

/// Placement constraints
pub const PlacementConstraints = struct {
    avoid_bank_crossing: bool = false,
    pack_registers_into_carry4: bool = false,
};

/// Routing constraints
pub const RoutingConstraints = struct {
    maximize_clock_skew: bool = false,
    use_fast_paths: bool = true,
};

/// All constraints
pub const Constraints = struct {
    timing: TimingConstraints = .{},
    placement: PlacementConstraints = .{},
    routing: RoutingConstraints = .{},
};

/// FSM state transitions
pub const FSMTransition = struct {
    from: []const u8,
    to: []const u8,
};

/// Behavior definition
pub const Behavior = struct {
    fsm_states: array_list.AlignedManaged([]const u8, null),
    fsm_transitions: array_list.AlignedManaged(FSMTransition, null),
    baud_divisor: ?u32 = null,
    template_path: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) Behavior {
        return .{
            .fsm_states = array_list.AlignedManaged([]const u8, null).init(allocator),
            .fsm_transitions = array_list.AlignedManaged(FSMTransition, null).init(allocator),
        };
    }
};

/// Testbench definition
pub const Testbench = struct {
    waveform_path: ?[]const u8 = null,
    test_frames: u32 = 10,
    test_data: array_list.AlignedManaged(u8, null),

    pub fn init(allocator: std.mem.Allocator) Testbench {
        return .{
            .test_data = array_list.AlignedManaged(u8, null).init(allocator),
        };
    }
};

/// Complete design specification
pub const DesignSpec = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    device: []const u8,
    module_type: ModuleType,
    consciousness_enabled: bool,
    override_strategy: ?Strategy,
    ports: array_list.AlignedManaged(Port, null),
    constraints: Constraints,
    behavior: Behavior,
    testbench: ?Testbench,

    /// Initialize design spec
    pub fn init(allocator: std.mem.Allocator) DesignSpec {
        return .{
            .allocator = allocator,
            .name = "",
            .device = "xc7a100t",
            .module_type = .custom,
            .consciousness_enabled = false,
            .override_strategy = null,
            .ports = array_list.AlignedManaged(Port, null).init(allocator),
            .constraints = .{},
            .behavior = Behavior.init(allocator),
            .testbench = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *DesignSpec) void {
        self.ports.deinit();
        self.behavior.fsm_states.deinit();
        self.behavior.fsm_transitions.deinit();
        if (self.testbench) |*tb| {
            tb.test_data.deinit();
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SYNTHESIS RESULT
// ═══════════════════════════════════════════════════════════════════════════════

/// Synthesis verdict
pub const Verdict = enum {
    PASS,
    FAIL,
    IN_PROGRESS,
};

/// Resource usage
pub const ResourceUsage = struct {
    lut: struct { used: u32, total: u32 } = .{ .used = 0, .total = 0 },
    ff: struct { used: u32, total: u32 } = .{ .used = 0, .total = 0 },
    iob: struct { used: u32, total: u32 } = .{ .used = 0, .total = 0 },
    bram: struct { used: u32, total: u32 } = .{ .used = 0, .total = 0 },
    dsp: struct { used: u32, total: u32 } = .{ .used = 0, .total = 0 },
};

/// Synthesis result
pub const SynthesisResult = struct {
    allocator: std.mem.Allocator,
    design_name: []const u8,
    success: bool,
    verdict: Verdict,
    strategy: Strategy,
    attempts: u32,
    runtime_ms: u64,
    timing_slack_ns: f64,
    resource_usage: ResourceUsage,
    root_cause: []const u8,
    bitstream_path: ?[]const u8,

    /// Initialize synthesis result
    pub fn init(allocator: std.mem.Allocator, design_name: []const u8) SynthesisResult {
        return .{
            .allocator = allocator,
            .design_name = design_name,
            .success = false,
            .verdict = .IN_PROGRESS,
            .strategy = .Balanced,
            .attempts = 0,
            .runtime_ms = 0,
            .timing_slack_ns = 0.0,
            .resource_usage = .{},
            .root_cause = "",
            .bitstream_path = null,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *SynthesisResult) void {
        self.allocator.free(self.root_cause);
        if (self.bitstream_path) |path| {
            self.allocator.free(path);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════════

test "SynthesisTypes: strategy_params_default" {
    const params = StrategyParams.default();
    try std.testing.expectEqual(PHI_INV, params.placement_cooling_alpha);
    try std.testing.expectEqual(@as(u32, 30), params.routing_iterations);
    try std.testing.expectEqual(50.0, params.target_frequency_mhz);
}

test "SynthesisTypes: strategy_params_aggressive" {
    const params = StrategyParams.aggressiveTiming();
    try std.testing.expectEqual(0.9, params.placement_cooling_alpha);
    try std.testing.expectEqual(@as(u32, 50), params.routing_iterations);
    try std.testing.expectEqual(60.0, params.target_frequency_mhz);
}

test "SynthesisTypes: strategy_params_conservative" {
    const params = StrategyParams.conservative();
    try std.testing.expectEqual(0.5, params.placement_cooling_alpha);
    try std.testing.expectEqual(@as(u32, 20), params.routing_iterations);
    try std.testing.expectEqual(40.0, params.target_frequency_mhz);
}

test "SynthesisTypes: design_spec_init" {
    const spec = DesignSpec.init(std.testing.allocator);
    defer spec.deinit();
    try std.testing.expectEqual(@as(usize, 0), spec.ports.items.len);
    try std.testing.expectEqual(.custom, spec.module_type);
}

test "SynthesisTypes: synthesis_result_init" {
    var result = SynthesisResult.init(std.testing.allocator, "test_module");
    defer result.deinit();
    try std.testing.expectEqual(.IN_PROGRESS, result.verdict);
    try std.testing.expectEqual(@as(u32, 0), result.attempts);
}
